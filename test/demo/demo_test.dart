import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/features/demo/data/local_demo_repository.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  late LocalDemoRepository demo;
  setUp(() async {
    store = await TestStore.open();
    demo = LocalDemoRepository(store.db, store.auth, clock: store.clock);
  });
  tearDown(() => store.close());
  test(
    'optional seed posts coherent sample records once and preserves owner',
    () async {
      final owner = (await store.auth.restore())!.userId;
      expect(await demo.availability(), DemoAvailability.ready);
      expect(await store.products.list(), isEmpty);
      await demo.load();
      await demo.load();
      expect(await demo.availability(), DemoAvailability.loaded);
      expect((await store.auth.restore())!.userId, owner);
      final products = await store.products.list();
      expect(products, hasLength(2));
      expect(
        products.singleWhere((p) => p.sku == 'DEMO-RICE').stockScaled,
        98000000000,
      );
      expect(
        (await store.db.select(
          'SELECT SUM(amount_delta_minor) AS balance FROM customer_ledger_entries',
        )).single['balance'],
        37000,
      );
      expect(
        (await store.db.select(
          'SELECT SUM(amount_delta_minor) AS balance FROM supplier_ledger_entries',
        )).single['balance'],
        1200000,
      );
      expect(await store.db.select('SELECT * FROM expenses'), hasLength(1));
      expect(await store.db.select('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test('existing data cannot be mixed with demo samples', () async {
    final id = await store.products.save(TestStore.product());
    expect(await demo.availability(), DemoAvailability.existingData);
    await expectLater(demo.load(), throwsA(isA<ValidationException>()));
    expect((await store.products.list()).single.id, id);
    expect(await store.db.select('SELECT * FROM suppliers'), isEmpty);
  });
  test(
    'failure at final audit rolls back all demo data and allows safe retry',
    () async {
      await store.db.execute(
        "CREATE TRIGGER fail_demo BEFORE INSERT ON audit_events WHEN NEW.action='load_demo' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(demo.load(), throwsA(isA<DatabaseException>()));
      for (final table in [
        'products',
        'product_prices',
        'purchases',
        'sales',
        'customers',
        'suppliers',
        'stock_transactions',
        'payments',
        'expenses',
        'customer_ledger_entries',
        'supplier_ledger_entries',
      ]) {
        expect(
          await store.db.select('SELECT * FROM $table'),
          isEmpty,
          reason: table,
        );
      }
      expect(await demo.availability(), DemoAvailability.ready);
      await store.db.execute('DROP TRIGGER fail_demo');
      await demo.load();
      expect(await demo.availability(), DemoAvailability.loaded);
    },
  );
}
