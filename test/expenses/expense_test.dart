import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/features/expenses/data/local_expense_repository.dart';
import 'package:shop_manager/services/id_service.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  late LocalExpenseRepository expenses;
  setUp(() async {
    store = await TestStore.open();
    expenses = LocalExpenseRepository(store.db, store.auth, clock: store.clock);
  });
  tearDown(() => store.close());
  test('expense/payment/audit are atomic, immutable and retry-safe with no stock or party ledger', () async {
    final id = IdService.newId(), date = store.clock();
    for (var i = 0; i < 2; i++) {
      await expenses.post(
        category: 'Rent',
        description: 'September rent',
        amount: '1250.50',
        occurredAt: date,
        requestId: id,
      );
    }
    expect((await expenses.list()).single['total_minor'], 125050);
    expect(
      (await store.db.select('SELECT * FROM payments')).single['expense_id'],
      id,
    );
    for (final table in [
      'stock_transactions',
      'customer_ledger_entries',
      'supplier_ledger_entries',
    ]) {
      expect(await store.db.select('SELECT * FROM $table'), isEmpty);
    }
    await expectLater(
      store.db.execute('UPDATE expenses SET total_minor=1 WHERE id=?', [id]),
      throwsA(isA<DatabaseException>()),
    );
    await store.db.execute(
      "CREATE TRIGGER fail_expense BEFORE INSERT ON audit_events WHEN NEW.action='post_expense' BEGIN SELECT RAISE(ABORT,'test'); END",
    );
    await expectLater(
      expenses.post(
        category: 'Transport',
        description: 'Delivery',
        amount: '10',
        occurredAt: date,
        requestId: IdService.newId(),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await expenses.list(), hasLength(1));
    expect(await store.db.select('SELECT * FROM payments'), hasLength(1));
  });
  test('invalid amounts and expired access fail without writes', () async {
    for (final value in ['0', '-1', '1.001', '1e4']) {
      await expectLater(
        expenses.post(
          category: 'Rent',
          description: 'Rent',
          amount: value,
          occurredAt: store.clock(),
          requestId: IdService.newId(),
        ),
        throwsA(isA<ValidationException>()),
      );
    }
    store.offset = const Duration(hours: 13).inMilliseconds;
    await expectLater(expenses.list(), throwsA(isA<ValidationException>()));
    expect(await store.db.select('SELECT * FROM expenses'), isEmpty);
  });
}
