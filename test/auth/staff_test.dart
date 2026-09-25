import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/permissions/permissions.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:shop_manager/core/money/money.dart';
import 'package:shop_manager/features/auth/data/local_staff_repository.dart';
import 'package:shop_manager/features/auth/data/local_auth_repository.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';
import 'package:shop_manager/features/inventory/data/local_inventory_repository.dart';
import 'package:shop_manager/features/expenses/data/local_expense_repository.dart';
import 'package:shop_manager/services/id_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  late LocalStaffRepository staff;
  setUp(() async {
    store = await TestStore.open();
    staff = LocalStaffRepository(
      store.db,
      store.auth,
      store.hasher,
      clock: store.clock,
    );
  });
  tearDown(() => store.close());
  test('cashier can sell and collect customer debt but cannot access owner modules', () async {
    final product = await store.products.save(
      TestStore.product(),
      opening: store.opening(),
    );
    final revision = (await store.products.details(product)).product.revision;
    await staff.create(
      name: 'Cashier',
      username: 'cashier',
      password: '654321',
    );
    final cashier = await store.auth.login('cashier', '654321');
    expect(cashier.role, ShopRole.cashier);
    expect((await store.auth.restore())!.role, ShopRole.cashier);
    final trade = LocalTradeRepository(store.db, store.auth);
    final customer = await trade.saveParty(PartyKind.customer, name: 'Buyer');
    final catalog = await trade.catalog(TradeKind.sale);
    expect(catalog.single.rate, '260');
    final sale = await trade.post(
      TradeKind.sale,
      TradeInput(
        partyId: customer,
        occurredAt: store.clock(),
        lines: [
          TradeLineInput(
            productId: product,
            unit: 'kg',
            quantity: '1',
            rate: '260',
            expectedRevision: revision,
          ),
        ],
      ),
    );
    expect(
      (await trade.document(TradeKind.sale, sale))['created_by'],
      cashier.userId,
    );
    await trade.settle(
      PartyKind.customer,
      customer,
      currency: Currency.pkr,
      amountText: '260',
      expectedBalance: 26000,
      occurredAt: store.clock(),
      requestId: IdService.newId(),
    );
    expect((await trade.khata(PartyKind.customer, customer)).single.balance, 0);
    for (final operation in <Future<Object?> Function()>[
      () => staff.list(),
      () => staff.create(
        name: 'Escalation',
        username: 'newstaff',
        password: '123456',
      ),
      () => store.products.list(),
      () => trade.catalog(TradeKind.purchase),
      () => trade.parties(PartyKind.supplier),
      () => trade.khata(PartyKind.supplier, customer),
      () => LocalInventoryRepository(store.db, store.auth).list(),
      () => LocalExpenseRepository(store.db, store.auth).list(),
    ]) {
      await expectLater(operation(), throwsA(isA<ValidationException>()));
    }
  });
  test('deactivation revokes live sessions; reactivation requires fresh login; owner cannot be disabled', () async {
    final owner = (await store.auth.restore())!;
    final id = await staff.create(
      name: 'Cashier',
      username: 'cashier',
      password: '654321',
    );
    final otherAuth = LocalAuthRepository(
      store.db,
      store.hasher,
      MemoryVault(),
      clock: store.clock,
    );
    await otherAuth.login('cashier', '654321');
    await staff.setActive(id, false, 1);
    expect(await otherAuth.restore(), isNull);
    await expectLater(
      otherAuth.login('cashier', '654321'),
      throwsA(isA<ValidationException>()),
    );
    await staff.setActive(id, true, 2);
    expect(await otherAuth.restore(), isNull);
    expect((await otherAuth.login('cashier', '654321')).role, ShopRole.cashier);
    await expectLater(
      staff.setActive(owner.userId, false, 1),
      throwsA(isA<ValidationException>()),
    );
    expect((await store.auth.restore())!.role, ShopRole.owner);
    await expectLater(
      staff.setActive(id, false, 1),
      throwsA(isA<ValidationException>()),
    );
  });
  test(
    'duplicate username and audit failure cannot leave partial staff account',
    () async {
      await expectLater(
        staff.create(
          name: 'Duplicate',
          username: 'owner@example.com',
          password: '654321',
        ),
        throwsA(isA<ValidationException>()),
      );
      await store.db.execute(
        "CREATE TRIGGER fail_staff BEFORE INSERT ON audit_events WHEN NEW.action='create_cashier' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        staff.create(name: 'Cashier', username: 'cashier', password: '654321'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await staff.list(), isEmpty);
      expect(
        await store.db.select('SELECT * FROM owner_credentials'),
        hasLength(1),
      );
    },
  );
}
