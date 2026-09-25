import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../../../shared/widgets/form_support.dart';
import '../../auth/application/session_provider.dart';
import '../application/trade_providers.dart';
import '../domain/trade.dart';
import 'trade_widgets.dart';
import 'purchase_detail_content.dart';

class TradeListScreen extends ConsumerWidget {
  const TradeListScreen(this.kind, {super.key});
  final TradeKind kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => TradeEditor(kind)),
            ),
            icon: const Icon(Icons.add),
            label: Text('New ${kind.label.toLowerCase()}'),
          ),
        ),
      ),
      Expanded(
        child: AsyncPanel(
          value: ref.watch(documentsProvider(kind)),
          retry: () => ref.invalidate(documentsProvider(kind)),
          data: (rows) => rows.isEmpty
              ? Center(child: Text('No ${kind.table} yet.'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final c = Currency(
                      row['currency_code'] as String,
                      minorDigits: row['currency_minor_digits'] as int,
                    );
                    return ListTile(
                      title: Text(row['party_name'] as String),
                      subtitle: Text(
                        '${dateText(row['occurred_at'] as int)} · ${row['status']}',
                      ),
                      trailing: Text(moneyText(row['total_minor'] as int, c)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TradeDetail(kind, row['id'] as String),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );
}

class TradeEditor extends ConsumerStatefulWidget {
  const TradeEditor(this.kind, {super.key});
  final TradeKind kind;
  @override
  ConsumerState<TradeEditor> createState() => _TradeEditorState();
}

class _TradeEditorState extends ConsumerState<TradeEditor> {
  String? partyId;
  DateTime date = DateTime.now();
  final lines = <({TradeLineInput input, String name, int total})>[];
  final paid = TextEditingController(text: '0'),
      discount = TextEditingController(text: '0'),
      note = TextEditingController();
  bool busy = false;
  String? error;
  Currency get currency =>
      ref.read(sessionProvider).asData!.value.shop!.currency;
  @override
  void dispose() {
    paid.dispose();
    discount.dispose();
    note.dispose();
    super.dispose();
  }

  TradeTotals get totals => TradeTotals.calculate(
    lines.map((l) => l.total).toList(),
    Money.parse(discount.text, currency),
    Money.parse(paid.text, currency),
  );
  Future<void> addLine(List<CatalogItem> catalog) async {
    final result =
        await Navigator.push<({TradeLineInput input, String name, int total})>(
          context,
          MaterialPageRoute(builder: (_) => _LineEditor(catalog, currency)),
        );
    if (result != null && mounted) setState(() => lines.add(result));
  }

  Future<void> save() async {
    if (partyId == null) {
      setState(
        () => error = 'Choose a ${widget.kind.party.label.toLowerCase()}.',
      );
      return;
    }
    if (!await confirmAction(
      context,
      'Post ${widget.kind.label.toLowerCase()}?',
      'This records stock and account entries. Completed documents cannot be edited.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await (await ref.read(tradeRepositoryProvider.future)).post(
        widget.kind,
        TradeInput(
          partyId: partyId!,
          lines: lines.map((l) => l.input).toList(),
          occurredAt: date.millisecondsSinceEpoch,
          paid: paid.text,
          discount: discount.text,
          note: note.text,
        ),
      );
      tradeChanged(ref);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => TradeDetail(widget.kind, id)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parties = ref.watch(partiesProvider(widget.kind.party));
    final catalog = ref.watch(catalogProvider(widget.kind));
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text('New ${widget.kind.label.toLowerCase()}')),
        body: SafeArea(
          child: AsyncPanel(
            value: parties,
            retry: () => ref.invalidate(partiesProvider(widget.kind.party)),
            data: (contacts) => AsyncPanel(
              value: catalog,
              retry: () => ref.invalidate(catalogProvider(widget.kind)),
              data: (products) => AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (contacts.where((p) => p['status'] == 'active').isEmpty)
                      Text(
                        'Add an active ${widget.kind.party.label.toLowerCase()} first.',
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: partyId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: widget.kind.party.label,
                      ),
                      items: contacts
                          .where((p) => p['status'] == 'active')
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => partyId = v),
                    ),
                    DateField(
                      value: date,
                      onChanged: (v) => setState(() => date = v),
                    ),
                    const Divider(),
                    for (var i = 0; i < lines.length; i++)
                      Card(
                        child: ListTile(
                          title: Text(lines[i].name),
                          subtitle: Text(
                            '${lines[i].input.quantity} ${lines[i].input.unit} × ${lines[i].input.rate}\n${moneyText(lines[i].total, currency)}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove item',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => lines.removeAt(i)),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: products.isEmpty
                          ? null
                          : () => addLine(products),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                    if (products.isEmpty)
                      const Text(
                        'Add an active product with pricing and units first.',
                      ),
                    const SizedBox(height: 20),
                    if (widget.kind == TradeKind.sale)
                      EntryField(
                        discount,
                        'Discount amount',
                        numeric: true,
                        hint:
                            'Fixed amount in ${currency.code}; not a percentage',
                      ),
                    EntryField(paid, 'Paid amount', numeric: true),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () {
                            try {
                              final due = TradeTotals.calculate(
                                lines.map((l) => l.total).toList(),
                                Money.parse(discount.text, currency),
                                0,
                              );
                              setState(() {
                                paid.text = Money.format(due.total, currency);
                                error = null;
                              });
                            } catch (e) {
                              setState(() => error = actionError(e));
                            }
                          },
                          child: const Text('Pay in full'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => paid.text = '0'),
                          child: const Text('Credit / pay later'),
                        ),
                      ],
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge([paid, discount]),
                      builder: (context, _) {
                        TradeTotals? t;
                        try {
                          t = totals;
                        } catch (_) {}
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AmountRow(
                              'Subtotal',
                              moneyText(
                                Money.sum(lines.map((l) => l.total)),
                                currency,
                              ),
                            ),
                            if (t != null) ...[
                              AmountRow(
                                'Total',
                                moneyText(t.total, currency),
                                emphasis: true,
                              ),
                              AmountRow(
                                'Remaining ${widget.kind == TradeKind.purchase ? 'payable' : 'balance'}',
                                moneyText(t.balance, currency),
                              ),
                              if (widget.kind == TradeKind.sale)
                                Text('Payment type: ${t.paymentType}'),
                            ] else
                              const Text(
                                'Enter valid discount and paid amounts.',
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    EntryField(note, 'Reference / note (optional)', lines: 2),
                    ErrorNotice(error),
                    FilledButton(
                      onPressed: busy || lines.isEmpty ? null : save,
                      child: Text(
                        busy
                            ? 'Saving…'
                            : 'Post ${widget.kind.label.toLowerCase()}',
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineEditor extends StatefulWidget {
  const _LineEditor(this.catalog, this.currency);
  final List<CatalogItem> catalog;
  final Currency currency;
  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  CatalogItem? product;
  String? unit;
  String search = '';
  final quantity = TextEditingController(text: '1'),
      rate = TextEditingController();
  String? error;
  @override
  void dispose() {
    quantity.dispose();
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add item')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search product',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(product?.id),
          initialValue: product?.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Product'),
          items: widget.catalog
              .where(
                (p) =>
                    p.id == product?.id ||
                    p.name.toLowerCase().contains(search),
              )
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: (id) => setState(() {
            product = widget.catalog.singleWhere((p) => p.id == id);
            unit = product!.pricingUnit;
            rate.text = product!.rate;
          }),
        ),
        const SizedBox(height: 16),
        if (product != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('${product!.id}:$unit'),
            initialValue: unit,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Transaction / pricing unit',
            ),
            items: product!.units
                .map(
                  (u) => DropdownMenuItem(
                    value: u.unitCode,
                    child: Text(u.unitCode),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              unit = v;
              rate.text = v == product!.pricingUnit ? product!.rate : '';
            }),
          ),
          const SizedBox(height: 16),
          EntryField(quantity, 'Quantity', numeric: true),
          EntryField(
            rate,
            'Rate per selected unit',
            numeric: true,
            hint: 'Enter an explicit rate when changing units.',
          ),
          ErrorNotice(error),
          FilledButton(
            onPressed: () {
              try {
                final q = Quantity.parse(quantity.text);
                if (q <= 0) throw const FormatException();
                final r = Money.parseUnitPrice(rate.text, widget.currency);
                if (r < 0) throw const FormatException();
                product!.units
                    .singleWhere((u) => u.unitCode == unit)
                    .normalize(q);
                Navigator.pop(context, (
                  input: TradeLineInput(
                    productId: product!.id,
                    unit: unit!,
                    quantity: quantity.text,
                    rate: rate.text,
                    expectedRevision: product!.revision,
                  ),
                  name: product!.name,
                  total: Money.lineTotal(
                    unitPriceTicks: r,
                    originalQuantityScaled: q,
                  ),
                ));
              } catch (_) {
                setState(
                  () => error = 'Enter a positive, representable quantity and a non-negative rate.',
                );
              }
            },
            child: const Text('Add to document'),
          ),
        ],
      ],
    ),
  );
}

class TradeDetail extends ConsumerWidget {
  const TradeDetail(this.kind, this.id, {super.key});
  final TradeKind kind;
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(
        kind == TradeKind.sale ? 'Receipt / Invoice' : 'Purchase details',
      ),
    ),
    body: AsyncPanel(
      value: ref.watch(documentProvider((kind: kind, id: id))),
      retry: () => ref.invalidate(documentProvider((kind: kind, id: id))),
      data: (row) {
        if (row['receipt_json'] == null) {
          return const Center(
            child: Text(
              'Details are unavailable for this older purchase or sale.',
            ),
          );
        }
        final receipt =
            jsonDecode(row['receipt_json'] as String) as Map<String, dynamic>;
        if (kind == TradeKind.purchase) {
          return PurchaseDetailContent(receipt: receipt, metadata: row);
        }
        final c = Currency(
          receipt['currency_code'] as String,
          minorDigits: receipt['currency_minor_digits'] as int,
        );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              receipt['shop_name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            for (final field in ['shop_phone', 'shop_address'])
              if (receipt[field] != null) Text(receipt[field] as String),
            const SizedBox(height: 16),
            SelectableText(receipt['number'] as String),
            Text(dateText(receipt['occurred_at'] as int)),
            Text('User: ${receipt['user_name']}'),
            Text('${kind.party.label}: ${receipt['party_name']}'),
            const Divider(height: 32),
            for (final item in receipt['items'] as List)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${Quantity.format(item['original_quantity_scaled'] as int)} ${item['original_unit_code']} × ${Money.formatUnitPrice(item['unit_price_ticks'] as int, c)}',
                    ),
                    Text(moneyText(item['line_total_minor'] as int, c)),
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
                moneyText(receipt[field] as int, c),
                emphasis: field == 'total',
              ),
            Text('Payment type: ${receipt['payment_type']}'),
            if (receipt['note'] != null) Text(receipt['note'] as String),
            const SizedBox(height: 20),
            const Text(
              'Amounts shown are at issue. This receipt preserves the original transaction.',
            ),
          ],
        );
      },
    ),
  );
}
