import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/money/money.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';
import 'package:shop_manager/database/row_writer.dart';
import 'package:shop_manager/services/id_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_store.dart';

void main() {
  for (final kind in [PartyKind.customer, PartyKind.supplier]) {
    group('${kind.label} khata', () {
      late TestStore store;
      late LocalTradeRepository trade;
      late String party, document;
      setUp(() async {
        store = await TestStore.open();
        trade = LocalTradeRepository(store.db, store.auth, clock: store.clock);
        party = await trade.saveParty(kind, name: 'Test contact');
        final product = await store.products.save(
          TestStore.product(),
          opening: store.opening(),
        );
        document = await trade.post(
          kind == PartyKind.customer ? TradeKind.sale : TradeKind.purchase,
          TradeInput(
            partyId: party,
            occurredAt: store.clock(),
            paid: '20',
            lines: [
              TradeLineInput(
                productId: product,
                unit: 'kg',
                quantity: '1',
                rate: '100',
                expectedRevision: (await store.products.details(product))
                    .product
                    .revision,
              ),
            ],
          ),
        );
      });
      tearDown(() => store.close());
      Future<String> pay(String value, int balance, {String? id, int? date}) =>
          trade.settle(
            kind,
            party,
            currency: Currency.pkr,
            amountText: value,
            expectedBalance: balance,
            occurredAt: date ?? store.clock(),
            requestId: id ?? IdService.newId(),
          );
      test(
        'partial/full payment, stable receipt and idempotent retry',
        () async {
          final type = kind == PartyKind.customer
              ? TradeKind.sale
              : TradeKind.purchase;
          final receipt = (await trade.document(
            type,
            document,
          ))['receipt_json'];
          final before = (await trade.khata(kind, party)).single;
          expect(before.balance, 8000);
          expect(before.entries.map((e) => e['running_balance']), [
            10000,
            8000,
          ]);
          final id = IdService.newId(), date = store.clock();
          await pay('30', 8000, id: id, date: date);
          await pay('30', 8000, id: id, date: date);
          expect((await trade.khata(kind, party)).single.balance, 5000);
          await pay('50', 5000);
          expect((await trade.khata(kind, party)).single.balance, 0);
          expect(
            (await trade.document(type, document))['receipt_json'],
            receipt,
          );
          expect(await store.db.select('SELECT * FROM payments'), hasLength(3));
          expect(
            (await store.db.select(
              'SELECT direction FROM payments WHERE id=?',
              [id],
            )).single['direction'],
            kind == PartyKind.customer ? 'incoming' : 'outgoing',
          );
        },
      );
      test(
        'overpayment, stale balance and zero amounts are rejected',
        () async {
          for (final future in [pay('81', 8000), pay('1', 1), pay('0', 8000)]) {
            await expectLater(future, throwsA(isA<ValidationException>()));
          }
          expect((await trade.khata(kind, party)).single.balance, 8000);
        },
      );
      test('late audit failure rolls back payment and ledger', () async {
        await store.db.execute(
          "CREATE TRIGGER fail_settlement BEFORE INSERT ON audit_events WHEN NEW.action='settle_${kind.name}' BEGIN SELECT RAISE(ABORT,'test'); END",
        );
        await expectLater(pay('10', 8000), throwsA(isA<DatabaseException>()));
        expect((await trade.khata(kind, party)).single.balance, 8000);
        expect(await store.db.select('SELECT * FROM payments'), hasLength(1));
      });
      test(
        'currency balances remain separate and archived contact can settle',
        () async {
          final owner = (await store.auth.restore())!;
          await RowWriter.insert(store.db, kind.ledger, {
            'shop_id': owner.shopId,
            kind.key: party,
            'status': 'posted',
            'created_by': owner.userId,
            'occurred_at': store.clock(),
            'currency_code': 'USD',
            'currency_minor_digits': 2,
            'entry_kind': 'opening_balance',
            'amount_delta_minor': 2500,
            'note': 'Legacy balance',
          }, store.clock());
          await trade.saveParty(
            kind,
            name: 'Test contact',
            id: party,
            revision: 1,
            active: false,
          );
          await pay('80', 8000);
          final accounts = await trade.khata(kind, party);
          expect(
            accounts.singleWhere((a) => a.currency.code == 'PKR').balance,
            0,
          );
          expect(
            accounts.singleWhere((a) => a.currency.code == 'USD').balance,
            2500,
          );
        },
      );
    });
  }
}
