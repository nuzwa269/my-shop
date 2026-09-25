import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/numeric/scaled_integer.dart';
import '../../../core/units/quantity.dart';
import '../../../services/repository_providers.dart';
import '../../../shared/widgets/form_support.dart';
import '../../auth/application/session_provider.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'unit_configuration_screen.dart';

class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({
    this.initial,
    this.configureUnitsFirst = false,
    super.key,
  });
  final ProductDetails? initial;
  final bool configureUnitsFirst;
  @override
  ConsumerState<ProductEditorScreen> createState() =>
      _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  final name = TextEditingController(),
      sku = TextEditingController(),
      description = TextEditingController(),
      purchase = TextEditingController(text: '0'),
      sale = TextEditingController(text: '0'),
      minimum = TextEditingController(text: '0'),
      base = TextEditingController(text: 'piece'),
      openingQty = TextEditingController(),
      openingValue = TextEditingController();
  String kind = 'weight',
      primary = 'kg',
      defaultSale = 'kg',
      purchaseUnit = 'kg',
      saleUnit = 'kg',
      openingUnit = 'kg';
  List<UnitConversion> units = [
    UnitConversion.grams(),
    UnitConversion.kilograms(),
  ];
  String? error;
  bool busy = false;
  String get baseUnit => kind == 'weight' ? 'gram' : units.first.baseUnit;
  @override
  void initState() {
    super.initState();
    final data = widget.initial;
    if (data != null) {
      final p = data.product;
      name.text = p.name;
      sku.text = p.sku ?? '';
      description.text = p.description ?? '';
      minimum.text = Quantity.format(p.minimumStockScaled);
      kind = p.measurementKind;
      base.text = p.baseUnit;
      units = data.units.isEmpty
          ? [
              UnitConversion(
                unitCode: p.baseUnit,
                baseUnit: p.baseUnit,
                numerator: 1,
                denominator: 1,
              ),
            ]
          : List.of(data.units);
      primary = p.primaryUnit;
      defaultSale = p.defaultSaleUnit;
      purchaseUnit = data.purchasePrice?.conversion.unitCode ?? primary;
      saleUnit = data.salePrice?.conversion.unitCode ?? defaultSale;
      if (data.purchasePrice != null) {
        purchase.text = ScaledInteger.format(
          data.purchasePrice!.amountTicks,
          decimals: data.purchasePrice!.currency.minorDigits + 4,
        );
      }
      if (data.salePrice != null) {
        sale.text = ScaledInteger.format(
          data.salePrice!.amountTicks,
          decimals: data.salePrice!.currency.minorDigits + 4,
        );
      }
    }
    if (widget.configureUnitsFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) configureUnits();
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      sku,
      description,
      purchase,
      sale,
      minimum,
      base,
      openingQty,
      openingValue,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void changeKind(String value) {
    setState(() {
      kind = value;
      final b = value == 'weight' ? 'gram' : 'piece';
      units = value == 'weight'
          ? [UnitConversion.grams(), UnitConversion.kilograms()]
          : [
              UnitConversion(
                unitCode: b,
                baseUnit: b,
                numerator: 1,
                denominator: 1,
              ),
            ];
      primary = defaultSale = purchaseUnit = saleUnit = openingUnit =
          value == 'weight' ? 'kg' : b;
      // Preserve entered prices only while their explicit units remain meaningful.
      purchase.text = '0';
      sale.text = '0';
      minimum.text = '0';
      openingQty.clear();
      openingValue.clear();
    });
  }

  Future<void> configureUnits() async {
    final result = await Navigator.push<List<UnitConversion>>(
      context,
      MaterialPageRoute(
        builder: (_) => UnitConfigurationScreen(
          units: units,
          baseUnit: baseUnit,
          requiredUnits: {
            primary,
            defaultSale,
            purchaseUnit,
            saleUnit,
            openingUnit,
          },
        ),
      ),
    );
    if (result != null && mounted) setState(() => units = result);
  }

  Widget unitChoice(String label, String value, ValueChanged<String> changed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: units
              .map(
                (u) => DropdownMenuItem(
                  value: u.unitCode,
                  child: Text(u.unitCode),
                ),
              )
              .toList(),
          onChanged: busy ? null : (v) => setState(() => changed(v!)),
        ),
      );
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      final id = await repository.save(
        ProductInput(
          name: name.text,
          sku: sku.text,
          description: description.text,
          baseUnit: baseUnit,
          measurementKind: kind,
          primaryUnit: primary,
          defaultSaleUnit: defaultSale,
          units: List.of(units),
          purchasePrice: purchase.text,
          purchasePriceUnit: purchaseUnit,
          salePrice: sale.text,
          salePriceUnit: saleUnit,
          minimumStock: minimum.text,
        ),
        id: widget.initial?.product.id,
        expectedRevision: widget.initial?.product.revision,
        opening:
            widget.initial == null &&
                (openingQty.text.trim().isNotEmpty ||
                    openingValue.text.trim().isNotEmpty)
            ? OpeningInput(
                quantity: openingQty.text,
                unit: openingUnit,
                totalValue: openingValue.text,
                occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              )
            : null,
      );
      ref.invalidate(productListProvider);
      ref.invalidate(productDetailsProvider(id));
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        ref.watch(sessionProvider).asData?.value.shop?.currency ?? Currency.pkr;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initial == null ? 'Add product' : 'Edit product'),
        ),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                EntryField(name, 'Product / variety name'),
                EntryField(sku, 'SKU / code (optional)'),
                EntryField(description, 'Description (optional)', lines: 2),
                if (widget.initial == null)
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Measurement'),
                    items: const [
                      DropdownMenuItem(
                        value: 'weight',
                        child: Text('Weight (base: gram)'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Count / custom (base: piece)'),
                      ),
                    ],
                    onChanged: (v) => changeKind(v!),
                  ),
                const SizedBox(height: 16),
                Text('Canonical base unit: $baseUnit'),
                if (kind == 'custom')
                  const Text(
                    'A piece is the explicit base count. Add other custom units as multiples of a piece.',
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: configureUnits,
                  icon: const Icon(Icons.straighten),
                  label: const Text('Configure units and conversions'),
                ),
                const SizedBox(height: 16),
                unitChoice(
                  'Primary stock display unit',
                  primary,
                  (v) => primary = v,
                ),
                unitChoice(
                  'Default sale unit',
                  defaultSale,
                  (v) => defaultSale = v,
                ),
                EntryField(
                  purchase,
                  'Purchase price (${currency.code})',
                  numeric: true,
                ),
                unitChoice(
                  'Purchase price per',
                  purchaseUnit,
                  (v) => purchaseUnit = v,
                ),
                EntryField(
                  sale,
                  'Sale price (${currency.code})',
                  numeric: true,
                ),
                unitChoice('Sale price per', saleUnit, (v) => saleUnit = v),
                const Text(
                  'Each price applies to one selected unit. Changing a unit or its factor saves a new price snapshot at the amount entered above.',
                ),
                const SizedBox(height: 16),
                EntryField(minimum, 'Minimum stock ($baseUnit)', numeric: true),
                if (widget.initial == null) ...[
                  const Divider(height: 32),
                  Text(
                    'Opening stock (optional)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  EntryField(
                    openingQty,
                    'Opening quantity',
                    numeric: true,
                    hint: 'Leave empty if there is no opening stock.',
                  ),
                  unitChoice(
                    'Opening unit',
                    openingUnit,
                    (v) => openingUnit = v,
                  ),
                  EntryField(
                    openingValue,
                    'Total opening value (${currency.code}, optional)',
                    numeric: true,
                  ),
                ],
                ErrorNotice(error),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving…' : 'Save product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
