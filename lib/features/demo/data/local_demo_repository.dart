import '../../../core/permissions/permissions.dart';
import '../../../core/units/quantity.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../../../services/id_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../../trade/data/local_trade_repository.dart';
import '../../trade/domain/trade.dart';
import '../../expenses/data/local_expense_repository.dart';

enum DemoAvailability { ready, loaded, existingData }

class LocalDemoRepository {
  LocalDemoRepository(this.db, this.auth, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final int Function() now;
  Future<DemoAvailability> _availability(SqlSession tx, String shop) async {
    if ((await tx.select(
      "SELECT id FROM settings WHERE shop_id=? AND key='demo_seed_v1'",
      [shop],
    )).isNotEmpty) {
      return DemoAvailability.loaded;
    }
    for (final table in [
      'products',
      'suppliers',
      'purchases',
      'sales',
      'expenses',
      'payments',
      'stock_transactions',
      'customer_ledger_entries',
      'supplier_ledger_entries',
    ]) {
      if ((await tx.select('SELECT id FROM $table WHERE shop_id=? LIMIT 1', [
        shop,
      ])).isNotEmpty) {
        return DemoAvailability.existingData;
      }
    }
    if ((await tx.select(
      'SELECT id FROM customers WHERE shop_id=? AND is_walk_in=0 LIMIT 1',
      [shop],
    )).isNotEmpty) {
      return DemoAvailability.existingData;
    }
    return DemoAvailability.ready;
  }

  Future<DemoAvailability> availability() => db.transaction((tx) async {
    final owner = await auth.authorize(tx, Permission.settings);
    return _availability(tx, owner.shopId);
  });
  Future<void> load() => db.transaction((tx) async {
    final owner = await auth.authorize(tx, Permission.settings);
    final available = await _availability(tx, owner.shopId);
    if (available == DemoAvailability.loaded) {
      return;
    }
    if (available != DemoAvailability.ready) {
      throw const ValidationException(
        'Demo data requires an empty shop. Existing data will not be changed.',
      );
    }
    // Existing repositories share this transaction; any failure rolls back the whole seed.
    final scoped = _DemoTransaction(tx);
    final products = LocalProductRepository(scoped, auth, clock: now);
    final trade = LocalTradeRepository(scoped, auth, clock: now);
    final expenses = LocalExpenseRepository(scoped, auth, clock: now);
    ProductInput product(String name, String sku, String minimum) =>
        ProductInput(
          name: name,
          sku: sku,
          description: 'Optional demo sample',
          baseUnit: 'gram',
          measurementKind: 'weight',
          primaryUnit: 'kg',
          defaultSaleUnit: 'kg',
          purchasePrice: '12000',
          purchasePriceUnit: 'bag',
          salePrice: '260',
          salePriceUnit: 'kg',
          minimumStock: minimum,
          units: [
            UnitConversion.grams(),
            UnitConversion.kilograms(),
            UnitConversion(
              unitCode: 'bag',
              baseUnit: 'gram',
              numerator: 50000,
              denominator: 1,
            ),
          ],
        );
    final rice = await products.save(
      product('DEMO Basmati rice', 'DEMO-RICE', '10000'),
    );
    await products.save(
      product('DEMO Flour', 'DEMO-FLOUR', '5000'),
      opening: OpeningInput(
        quantity: '2',
        unit: 'kg',
        occurredAt: now(),
        reason: 'Demo opening stock',
      ),
    );
    final supplier = await trade.saveParty(
      PartyKind.supplier,
      name: 'DEMO Grain Mill',
      note: 'Demo supplier',
    );
    final customer = await trade.saveParty(
      PartyKind.customer,
      name: 'DEMO Customer',
      note: 'Demo customer',
    );
    await trade.post(
      TradeKind.purchase,
      TradeInput(
        partyId: supplier,
        occurredAt: now(),
        paid: '10000',
        note: 'Demo purchase',
        lines: [
          TradeLineInput(
            productId: rice,
            unit: 'bag',
            quantity: '2',
            rate: '12000',
            expectedRevision: 1,
          ),
        ],
      ),
    );
    await trade.post(
      TradeKind.sale,
      TradeInput(
        partyId: customer,
        occurredAt: now(),
        paid: '100',
        note: 'Demo credit sale',
        lines: [
          TradeLineInput(
            productId: rice,
            unit: 'kg',
            quantity: '2',
            rate: '260',
            expectedRevision: 1,
          ),
        ],
      ),
    );
    for (final (kind, id, amount) in [
      (PartyKind.customer, customer, '50'),
      (PartyKind.supplier, supplier, '2000'),
    ]) {
      final account = (await trade.khata(kind, id)).single;
      await trade.settle(
        kind,
        id,
        currency: account.currency,
        amountText: amount,
        expectedBalance: account.balance,
        occurredAt: now(),
        requestId: IdService.newId(),
        note: 'Demo account payment',
      );
    }
    await expenses.post(
      category: 'Transport',
      description: 'DEMO delivery expense',
      amount: '500',
      occurredAt: now(),
      requestId: IdService.newId(),
    );
    await RowWriter.insert(tx, 'settings', {
      'shop_id': owner.shopId,
      'key': 'demo_seed_v1',
      'value_json': 'true',
    }, now());
    await RowWriter.audit(
      tx,
      shopId: owner.shopId,
      actorId: owner.userId,
      table: 'shops',
      entityId: owner.shopId,
      action: 'load_demo',
      reason: 'Owner opted into sample transactions in an empty shop',
      now: now(),
    );
  });
}

/// Only used for the lifetime of load()'s outer transaction; never opens or closes storage.
class _DemoTransaction implements DatabaseConnection {
  const _DemoTransaction(this.tx);
  final SqlSession tx;
  @override
  Future<void> execute(String sql, [List<Object?> arguments = const []]) =>
      tx.execute(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) => tx.select(sql, arguments);
  @override
  Future<T> transaction<T>(Future<T> Function(SqlSession) action) => action(tx);
  @override
  Future<void> close() async =>
      throw StateError('Cannot close the demo transaction connection.');
}
