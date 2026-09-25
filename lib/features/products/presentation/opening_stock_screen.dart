import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';
import '../../../services/repository_providers.dart';
import '../../../shared/widgets/form_support.dart';
import '../../auth/application/session_provider.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';

class OpeningStockScreen extends ConsumerStatefulWidget {
  const OpeningStockScreen({required this.details, super.key});
  final ProductDetails details;
  @override
  ConsumerState<OpeningStockScreen> createState() => _OpeningStockScreenState();
}

class _OpeningStockScreenState extends ConsumerState<OpeningStockScreen> {
  final quantity = TextEditingController(), value = TextEditingController();
  late String unit;
  DateTime occurred = DateTime.now();
  bool busy = false;
  String? error;
  List<UnitConversion> get _uniqueUnits {
    final byCode = <String, UnitConversion>{};
    for (final conversion in widget.details.units) {
      byCode.putIfAbsent(
        conversion.unitCode.trim().toLowerCase(),
        () => conversion,
      );
    }
    return byCode.values.toList();
  }

  String get _selectedUnit {
    final selected = unit.trim().toLowerCase();
    return _uniqueUnits.any((item) => item.unitCode == selected)
        ? selected
        : _uniqueUnits.first.unitCode;
  }

  @override
  void initState() {
    super.initState();
    final previous = widget.details.opening;
    unit = widget.details.product.primaryUnit;
    if (previous != null) {
      quantity.text = Quantity.format(previous.quantity.originalQuantityScaled);
      final oldUnit = previous.quantity.conversion.unitCode;
      if (widget.details.units.any((u) => u.unitCode == oldUnit)) {
        unit = oldUnit;
      }
      occurred = DateTime.fromMillisecondsSinceEpoch(previous.occurredAt)
          .toLocal();
    }
    unit = _selectedUnit;
    quantity.addListener(_refreshEstimate);
  }

  void _refreshEstimate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    quantity.removeListener(_refreshEstimate);
    quantity.dispose();
    value.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (await ref.read(productRepositoryProvider.future)).setOpening(
        widget.details.product.id,
        OpeningInput(
          quantity: quantity.text,
          unit: unit,
          totalValue: value.text.trim().isNotEmpty
              ? value.text
              : _estimatedOpeningValue ?? _previousOpeningValue ?? '',
          reason: widget.details.opening == null
              ? 'Initial stock count'
              : 'Opening stock correction',
          occurredAt: occurred.toUtc().millisecondsSinceEpoch,
        ),
        expectedRevision: widget.details.product.revision,
        expectedOpeningId: widget.details.opening?.id,
      );
      ref.invalidate(productListProvider);
      ref.invalidate(productDetailsProvider(widget.details.product.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  ({int minorUnits, String display})? get _openingEstimate {
    final price = widget.details.purchasePrice;
    if (price == null || quantity.text.trim().isEmpty) return null;
    try {
      final conversion = _uniqueUnits.firstWhere(
        (item) => item.unitCode.trim().toLowerCase() == unit,
      );
      final snapshot = UnitConversionService.snapshot(
        quantity.text,
        conversion,
      );
      final total = UnitConversionService.priceTotal(
        priceTicks: price.amountTicks,
        pricingConversion: price.conversion,
        quantity: snapshot,
      );
      return (
        minorUnits: total,
        display:
            '${price.currency.code} ${Money.format(total, price.currency)}',
      );
    } catch (_) {
      return null;
    }
  }

  String? get _estimatedOpeningValue {
    final estimate = _openingEstimate;
    if (estimate == null) return null;
    final price = widget.details.purchasePrice!;
    return Money.format(estimate.minorUnits, price.currency);
  }

  String? get _previousOpeningValue {
    final previous = widget.details.opening;
    final currency = ref.read(sessionProvider).asData?.value.shop?.currency;
    if (previous?.valueMinor == null || currency == null) return null;
    return Money.format(previous!.valueMinor!, currency);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.details.opening == null
              ? 'Opening stock'
              : 'Correct opening stock',
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.details.product.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              EntryField(quantity, 'Opening quantity', numeric: true),
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: _uniqueUnits
                    .map((u) => u.unitCode.trim().toLowerCase())
                    .toSet()
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => unit = v!),
              ),
              if (_openingEstimate case final estimate?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Estimated opening value: ${estimate.display}'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opening date'),
                subtitle: Text(occurred.toLocal().toString().split(' ').first),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: occurred,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && mounted) setState(() => occurred = date);
                },
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced options'),
                children: [
                  EntryField(
                    value,
                    'Opening value override (optional)',
                    numeric: true,
                    hint: 'Leave blank to use the estimate, if available.',
                  ),
                ],
              ),
              ErrorNotice(error),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save opening stock'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
