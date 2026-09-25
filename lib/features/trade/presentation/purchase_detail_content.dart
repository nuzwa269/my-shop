import 'package:flutter/material.dart';

import '../../../core/formatting/display_format.dart';
import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import 'trade_widgets.dart';

class PurchaseDetailContent extends StatelessWidget {
  const PurchaseDetailContent({
    required this.receipt,
    required this.metadata,
    super.key,
  });

  final Map<String, dynamic> receipt;
  final Map<String, Object?> metadata;

  @override
  Widget build(BuildContext context) {
    final currency = Currency(
      receipt['currency_code'] as String,
      minorDigits: receipt['currency_minor_digits'] as int,
    );
    String amount(int value) =>
        '${currency.code} ${groupedDecimal(Money.format(value, currency))}';
    final sequence = metadata['display_sequence'] as int?;
    final reference = sequence == null
        ? 'Unavailable'
        : 'PUR-${sequence.toString().padLeft(4, '0')}';
    final creator = (receipt['user_name'] as String?)?.trim();
    final note = (receipt['note'] as String?)?.trim();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Purchase No: $reference',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Date: ${friendlyDate(receipt['occurred_at'] as int)}'),
        if (creator != null && creator.isNotEmpty) Text('Created by: $creator'),
        const SizedBox(height: 20),
        Text(
          'Supplier: ${receipt['party_name']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final entry in {'phone': 'Phone', 'address': 'Address'}.entries)
          if ((metadata['supplier_${entry.key}'] as String?)
                  ?.trim()
                  .isNotEmpty ??
              false)
            Text(
              '${entry.value}: ${(metadata['supplier_${entry.key}'] as String).trim()}',
            ),
        const Divider(height: 32),
        for (final item in receipt['items'] as List)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${Quantity.formatDisplay(item['original_quantity_scaled'] as int)} ${item['original_unit_code']}',
                ),
                Text(
                  'Rate: ${currency.code} ${groupedDecimal(Money.formatUnitPrice(item['unit_price_ticks'] as int, currency))} / ${item['original_unit_code']}',
                ),
                Text('Amount: ${amount(item['line_total_minor'] as int)}'),
              ],
            ),
          ),
        const Divider(),
        for (final field in [
          'subtotal',
          'discount',
          'total',
          'paid',
          'balance',
        ])
          AmountRow(
            field[0].toUpperCase() + field.substring(1),
            amount(receipt[field] as int),
            emphasis: field == 'total' || field == 'balance',
          ),
        AmountRow('Payment Type', switch (receipt['payment_type']) {
          'cash' => 'Cash',
          'credit' => 'Credit',
          'partial' => 'Partial payment',
          _ => 'Unavailable',
        }),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Note: $note'),
        ],
        const SizedBox(height: 16),
        const Text('Amounts shown are from the purchase date.'),
      ],
    );
  }
}
