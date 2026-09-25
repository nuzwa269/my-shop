import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/features/trade/application/trade_providers.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';
import 'package:shop_manager/features/trade/presentation/trade_screens.dart';

void main() {
  const internalId = '01e37ccd-3945-447a-81c0-661138fe1f22';
  Future<void> mount(
    WidgetTester tester, {
    bool fractional = false,
    bool contacts = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final receipt = {
      'number': 'P-$internalId',
      'occurred_at': DateTime(2026, 9, 25).millisecondsSinceEpoch,
      'party_name': 'Salt Supplier',
      'user_name': contacts ? 'Ali' : ' ',
      'currency_code': 'PKR',
      'currency_minor_digits': 2,
      'items': [
        {
          'product_id': internalId,
          'product_name': 'Salt',
          'original_quantity_scaled': fractional ? 1250000 : 50000000,
          'original_unit_code': 'kg',
          'unit_price_ticks': fractional ? 20123456 : 20000000,
          // Deliberately use a stored total: the UI must not recalculate it.
          'line_total_minor': 100000,
        },
      ],
      'subtotal': 100000,
      'discount': 0,
      'total': 100000,
      'paid': 30050,
      'balance': 69950,
      'payment_type': 'partial',
      'note': contacts ? 'Deliver tomorrow' : ' ',
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentProvider((kind: TradeKind.purchase, id: internalId))
              .overrideWith(
                (ref) async => {
                  'id': internalId,
                  'created_by': internalId,
                  'display_sequence': 1,
                  'supplier_phone': contacts ? '0300 1234567' : null,
                  'supplier_address': contacts ? 'Main Market' : ' ',
                  'receipt_json': jsonEncode(receipt),
                },
              ),
        ],
        child: const MaterialApp(
          home: TradeDetail(TradeKind.purchase, internalId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('purchase details are labeled and hide internal metadata', (
    tester,
  ) async {
    await mount(tester);
    for (final text in [
      'Purchase No: PUR-0001',
      'Date: 25 Sep 2026',
      'Created by: Ali',
      'Supplier: Salt Supplier',
      'Phone: 0300 1234567',
      'Address: Main Market',
      'Salt',
      'Qty: 50 kg',
      'Rate: PKR 20 / kg',
      'Amount: PKR 1,000',
      'Subtotal',
      'Discount',
      'Total',
      'Paid',
      'Balance',
      'Payment Type',
      'Partial payment',
      'PKR 300.50',
      'PKR 699.50',
      'Note: Deliver tomorrow',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.textContaining(internalId), findsNothing);
    expect(find.textContaining('50.000000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fractional quantities and rates retain precision; empty details are omitted',
    (tester) async {
      await mount(tester, fractional: true, contacts: false);
      expect(find.text('Qty: 1.25 kg'), findsOneWidget);
      expect(find.text('Rate: PKR 20.123456 / kg'), findsOneWidget);
      expect(find.text('Amount: PKR 1,000'), findsOneWidget);
      for (final label in ['Phone:', 'Address:', 'Created by:', 'Note:']) {
        expect(find.textContaining(label), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
