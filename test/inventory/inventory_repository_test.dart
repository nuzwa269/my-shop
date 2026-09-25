import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:shop_manager/features/inventory/data/local_inventory_repository.dart';
import 'package:shop_manager/features/inventory/domain/inventory.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  late LocalInventoryRepository inventory;
  setUp(() async {
    store = await TestStore.open();
    inventory = LocalInventoryRepository(store.db, store.auth);
  });
  tearDown(() => store.close());

  test('inventory retains opening correction history and exact purchase/sale movements', () async {
    final id = await store.products.save(
      TestStore.product(),
      opening: store.opening(quantity: '2'),
    );
    final before = await store.products.details(id);
    await store.products.setOpening(
      id,
      store.opening(quantity: '1', reason: 'Correct count'),
      expectedRevision: before.product.revision,
      expectedOpeningId: before.opening!.id,
    );
    final product = (await store.products.details(id)).product;
    final trade = LocalTradeRepository(store.db, store.auth);
    final supplier = await trade.saveParty(PartyKind.supplier, name: 'Mill');
    final customer = await trade.saveParty(
      PartyKind.customer,
      name: 'Customer',
    );
    await trade.post(
      TradeKind.purchase,
      TradeInput(
        partyId: supplier,
        occurredAt: store.clock(),
        lines: [
          TradeLineInput(
            productId: id,
            unit: 'bag',
            quantity: '1',
            rate: '12000',
            expectedRevision: product.revision,
          ),
        ],
      ),
    );
    await trade.post(
      TradeKind.sale,
      TradeInput(
        partyId: customer,
        occurredAt: store.clock(),
        lines: [
          TradeLineInput(
            productId: id,
            unit: 'kg',
            quantity: '2',
            rate: '260',
            expectedRevision: product.revision,
          ),
        ],
      ),
    );
    final details = await inventory.details(id);
    expect(details.product.stockScaled, 98000000000);
    expect(details.movements, hasLength(5));
    expect(
      details.movements.fold<int>(0, (sum, m) => sum + m.delta),
      details.product.stockScaled,
    );
    expect(
      details.movements.where((m) => m.reason == 'reversal'),
      hasLength(1),
    );
    final sale = details.movements.singleWhere((m) => m.reason == 'sale');
    expect(sale.delta, -2000000000);
    expect(sale.quantity.originalQuantityScaled, 2000000);
    expect(sale.quantity.conversion.unitCode, 'kg');
    expect(
      (await inventory.list()).single.stockScaled,
      details.product.stockScaled,
    );
  });

  test(
    'zero, minimum threshold and inactive inventory remain distinguishable',
    () async {
      await store.products.save(
        TestStore.product(name: 'Empty', minimum: '1000'),
      );
      final id = await store.products.save(
        TestStore.product(name: 'Low', minimum: '50000'),
        opening: store.opening(quantity: '1'),
      );
      final items = await inventory.list();
      expect(
        items.where((p) => matchesStock(p, StockFilter.out)).single.name,
        'Empty',
      );
      expect(
        items.where((p) => matchesStock(p, StockFilter.low)).single.name,
        'Low',
      );
      expect(stockLabel(items.singleWhere((p) => p.id == id)), 'Low stock');
      final revision = (await store.products.details(id)).product.revision;
      await store.products.setActive(id, false, revision);
      final archived = await inventory.details(id);
      expect(archived.product.active, isFalse);
      expect(archived.product.stockScaled, 50000000000);
      expect(await inventory.list(), hasLength(2));
    },
  );

  test(
    'unknown product and expired sessions cannot expose inventory',
    () async {
      await expectLater(
        inventory.details('unknown'),
        throwsA(isA<ValidationException>()),
      );
      store.offset = const Duration(hours: 13).inMilliseconds;
      await expectLater(inventory.list(), throwsA(isA<Exception>()));
      await expectLater(
        inventory.details('unknown'),
        throwsA(isA<Exception>()),
      );
    },
  );
}
