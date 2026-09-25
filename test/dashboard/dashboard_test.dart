import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/features/dashboard/data/local_dashboard_repository.dart';
import 'package:shop_manager/features/demo/data/local_demo_repository.dart';
import 'package:shop_manager/features/auth/data/local_staff_repository.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  setUp(() async {
    store = await TestStore.open();
  });
  tearDown(() => store.close());
  test(
    'daily metrics, cumulative balances, stock counts and demo marker',
    () async {
      await LocalDemoRepository(
        store.db,
        store.auth,
        clock: store.clock,
      ).load();
      final dashboard = LocalDashboardRepository(
        store.db,
        store.auth,
        clock: store.clock,
      );
      final summary = await dashboard.summary();
      expect(summary.demo, isTrue);
      expect(summary.activeProducts, 2);
      expect(summary.lowStock, 1);
      expect(summary.outOfStock, 0);
      final m = summary.money.single;
      expect(m.sales, 52000);
      expect(m.purchases, 2400000);
      expect(m.expenses, 50000);
      expect(m.receivable, 37000);
      expect(m.payable, 1200000);
      final next = DateTime.fromMillisecondsSinceEpoch(store.clock())
          .add(const Duration(days: 1));
      final later = await LocalDashboardRepository(
        store.db,
        store.auth,
        clock: () => next.millisecondsSinceEpoch,
      ).summary();
      expect(later.money.single.sales, 0);
      expect(later.money.single.receivable, 37000);
    },
  );
  test('cashier metrics exclude owner sales and all costs/balances', () async {
    await LocalDemoRepository(store.db, store.auth).load();
    final staff = LocalStaffRepository(store.db, store.auth, store.hasher);
    await staff.create(
      name: 'Cashier',
      username: 'cashier',
      password: '123456',
    );
    await store.auth.login('cashier', '123456');
    final dashboard = LocalDashboardRepository(store.db, store.auth);
    var summary = await dashboard.summary();
    expect(summary.cashier, isTrue);
    expect(summary.money.single.sales, 0);
    final trade = LocalTradeRepository(store.db, store.auth);
    final customer = (await trade.parties(PartyKind.customer)).first;
    final product = (await trade.catalog(TradeKind.sale))
        .singleWhere((p) => p.name.contains('Basmati'));
    await trade.post(
      TradeKind.sale,
      TradeInput(
        partyId: customer['id'] as String,
        occurredAt: store.clock(),
        paid: '260',
        lines: [
          TradeLineInput(
            productId: product.id,
            unit: 'kg',
            quantity: '1',
            rate: '260',
            expectedRevision: product.revision,
          ),
        ],
      ),
    );
    summary = await dashboard.summary();
    expect(summary.money.single.sales, 26000);
    expect(summary.money.single.purchases, 0);
    expect(summary.money.single.expenses, 0);
    expect(summary.money.single.receivable, 0);
    expect(summary.money.single.payable, 0);
  });
}
