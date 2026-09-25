import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  late LocalTradeRepository trade;
  late String product, supplier, customer;
  setUp(() async {
    store = await TestStore.open();
    trade = LocalTradeRepository(store.db, store.auth, clock: store.clock);
    product = await store.products.save(TestStore.product());
    supplier = await trade.saveParty(PartyKind.supplier, name: 'Mill');
    customer = await trade.saveParty(PartyKind.customer, name: 'Aisha');
  });
  tearDown(() => store.close());

  TradeLineInput line({
    String quantity = '1',
    String unit = 'bag',
    String rate = '12000',
    int revision = 1,
  }) => TradeLineInput(
    productId: product,
    unit: unit,
    quantity: quantity,
    rate: rate,
    expectedRevision: revision,
  );
  TradeInput input(
    TradeKind kind, {
    List<TradeLineInput>? lines,
    String paid = '0',
    String discount = '0',
    String? party,
  }) => TradeInput(
    partyId: party ?? (kind == TradeKind.purchase ? supplier : customer),
    lines: lines ?? [line()],
    paid: paid,
    discount: discount,
    occurredAt: store.clock(),
  );
  Future<int> stock() async =>
      (await store.products.details(product)).product.stockScaled;
  Future<List<Map<String, Object?>>> ledger(PartyKind kind) => store.db.select(
    'SELECT * FROM ${kind.ledger} ORDER BY amount_delta_minor DESC',
  );

  test('purchase and discounted partial sale post exact stock, payments, ledgers and receipt snapshots', () async {
    final purchase = await trade.post(
      TradeKind.purchase,
      input(TradeKind.purchase, paid: '2000'),
    );
    final storedPurchase = (await store.db.select(
      'SELECT * FROM purchases WHERE id=?',
      [purchase],
    )).single;
    final purchaseDetail = await trade.document(TradeKind.purchase, purchase);
    expect(purchaseDetail['display_sequence'], 1);
    for (final entry in storedPurchase.entries) {
      expect(purchaseDetail[entry.key], entry.value);
    }
    expect(
      (await store.db.select('SELECT * FROM purchases WHERE id=?', [
        purchase,
      ])).single,
      storedPurchase,
    );
    expect(await stock(), 50000000000);
    expect(
      (await ledger(PartyKind.supplier)).map((r) => r['amount_delta_minor']),
      [1200000, -200000],
    );
    final sale = await trade.post(
      TradeKind.sale,
      input(
        TradeKind.sale,
        lines: [line(quantity: '2', unit: 'kg', rate: '260')],
        discount: '20',
        paid: '300',
      ),
    );
    expect(await stock(), 48000000000);
    expect(
      (await ledger(PartyKind.customer)).map((r) => r['amount_delta_minor']),
      [50000, -30000],
    );
    final row = await trade.document(TradeKind.sale, sale);
    final snapshot =
        jsonDecode(row['receipt_json'] as String) as Map<String, dynamic>;
    expect(snapshot['subtotal'], 52000);
    expect(snapshot['total'], 50000);
    expect(snapshot['balance'], 20000);
    expect(snapshot['payment_type'], 'partial');
    expect((snapshot['items'] as List).single['conversion_numerator'], 1000);
    final payments = await store.db.select(
      'SELECT * FROM payments ORDER BY direction',
    );
    expect(payments.map((r) => r['direction']), ['incoming', 'outgoing']);
    expect(payments.first['sale_id'], sale);
    expect(payments.last['purchase_id'], purchase);
    await store.products.save(
      TestStore.product(name: 'Renamed', bagGrams: 25000),
      id: product,
      expectedRevision: 1,
    );
    await trade.saveParty(
      PartyKind.customer,
      name: 'Renamed customer',
      id: customer,
      revision: 1,
    );
    expect(
      (await trade.document(TradeKind.sale, sale))['receipt_json'],
      row['receipt_json'],
    );
    await expectLater(
      store.db.execute("UPDATE sales SET receipt_json='{}' WHERE id=?", [sale]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      store.db.execute(
        "UPDATE sale_items SET product_name='Changed' WHERE sale_id=?",
        [sale],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await store.db.select('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
  });

  test(
    'aggregated duplicate lines and competing sales cannot oversell',
    () async {
      await trade.post(TradeKind.purchase, input(TradeKind.purchase));
      await expectLater(
        trade.post(
          TradeKind.sale,
          input(TradeKind.sale, lines: [line(), line()]),
        ),
        throwsA(isA<ValidationException>()),
      );
      final results = await Future.wait(
        List.generate(2, (_) async {
          try {
            await trade.post(TradeKind.sale, input(TradeKind.sale));
            return true;
          } on ValidationException {
            return false;
          }
        }),
      );
      expect(results.where((r) => r), hasLength(1));
      expect(await stock(), 0);
      expect(await trade.documents(TradeKind.sale), hasLength(1));
    },
  );

  test('audit failure rolls back documents, items, stock, payment and ledger together', () async {
    await store.db.execute(
      "CREATE TRIGGER reject_trade_audit BEFORE INSERT ON audit_events WHEN NEW.action='post_purchase' BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
    await expectLater(
      trade.post(TradeKind.purchase, input(TradeKind.purchase, paid: '12000')),
      throwsA(isA<DatabaseException>()),
    );
    for (final table in [
      'purchases',
      'purchase_items',
      'stock_transactions',
      'payments',
      'supplier_ledger_entries',
    ]) {
      expect(
        await store.db.select('SELECT * FROM $table'),
        isEmpty,
        reason: table,
      );
    }
    expect(await stock(), 0);
  });

  test(
    'walk-in is unique and retained; credit requires a named customer',
    () async {
      final walkIn = (await trade.parties(PartyKind.customer))
          .singleWhere((p) => p['is_walk_in'] == 1);
      expect(
        (await trade.parties(PartyKind.customer))
            .where((p) => p['is_walk_in'] == 1),
        hasLength(1),
      );
      await trade.post(TradeKind.purchase, input(TradeKind.purchase));
      await expectLater(
        trade.post(
          TradeKind.sale,
          input(TradeKind.sale, party: walkIn['id'] as String),
        ),
        throwsA(isA<ValidationException>()),
      );
      await trade.post(
        TradeKind.sale,
        input(TradeKind.sale, party: walkIn['id'] as String, paid: '12000'),
      );
      expect(
        (await ledger(PartyKind.customer)).map((r) => r['amount_delta_minor']),
        [1200000, -1200000],
      );
      await expectLater(
        trade.saveParty(
          PartyKind.customer,
          id: walkIn['id'] as String,
          revision: 1,
          name: 'Changed',
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        store.db.execute('DELETE FROM customers WHERE id=?', [walkIn['id']]),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('stale products, inactive parties, invalid precision, payment and discount are rejected', () async {
    for (final invalid in [
      input(TradeKind.purchase, lines: [line(revision: 2)]),
      input(TradeKind.purchase, lines: [line(quantity: '0')]),
      input(TradeKind.purchase, lines: [line(quantity: '1.0000001')]),
      input(TradeKind.purchase, lines: [line(unit: 'missing')]),
      input(TradeKind.purchase, lines: [line(rate: '-1')]),
      input(TradeKind.purchase, paid: '12001'),
      input(TradeKind.purchase, discount: '1'),
      input(TradeKind.purchase, discount: '-1'),
    ]) {
      await expectLater(
        trade.post(TradeKind.purchase, invalid),
        throwsA(isA<ValidationException>()),
      );
    }
    await trade.saveParty(
      PartyKind.supplier,
      name: 'Mill',
      id: supplier,
      revision: 1,
      active: false,
    );
    await expectLater(
      trade.post(TradeKind.purchase, input(TradeKind.purchase)),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      trade.saveParty(
        PartyKind.supplier,
        name: 'Stale',
        id: supplier,
        revision: 1,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await trade.documents(TradeKind.purchase), isEmpty);
  });

  test(
    'fractional quantities round once per line and preserve explicit factors',
    () async {
      await trade.post(
        TradeKind.purchase,
        input(
          TradeKind.purchase,
          lines: [line(quantity: '0.000001', unit: 'kg', rate: '5000')],
          paid: '0.01',
        ),
      );
      expect(await stock(), 1000);
      expect(
        (await trade.documents(TradeKind.purchase)).single['total_minor'],
        1,
      );
      expect(
        (await ledger(PartyKind.supplier)).map((r) => r['amount_delta_minor']),
        [1, -1],
      );
    },
  );

  test('expired authentication cannot post or create contacts', () async {
    store.offset = const Duration(hours: 13).inMilliseconds;
    await expectLater(
      trade.post(TradeKind.purchase, input(TradeKind.purchase)),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      trade.saveParty(PartyKind.customer, name: 'Unauthorized'),
      throwsA(isA<Exception>()),
    );
    expect(await store.db.select('SELECT * FROM purchases'), isEmpty);
  });
}
