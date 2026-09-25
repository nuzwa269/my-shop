import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/numeric/scaled_integer.dart';
import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';
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
  bool advanced = false;
  String minimumUnit = 'kg';
  String get baseUnit => kind == 'weight' ? 'gram' : units.first.baseUnit;

  static List<UnitConversion> _normalizeUnits(
    Iterable<UnitConversion> source,
    String base,
    String measurementKind,
  ) {
    final byCode = <String, UnitConversion>{};
    for (final unit in source) {
      final code = unit.unitCode.trim().toLowerCase();
      if (code.isEmpty || byCode.containsKey(code)) continue;
      byCode[code] = UnitConversion(
        unitCode: code,
        baseUnit: unit.baseUnit.trim().toLowerCase(),
        numerator: unit.numerator,
        denominator: unit.denominator,
      );
    }
    if (measurementKind == 'weight') {
      byCode['gram'] = UnitConversion.grams();
      byCode['kg'] = UnitConversion.kilograms();
    } else {
      byCode[base] = UnitConversion(
        unitCode: base,
        baseUnit: base,
        numerator: 1,
        denominator: 1,
      );
    }
    return byCode.values.toList();
  }

  String _safeUnit(String requested) {
    final normalized = requested.trim().toLowerCase();
    if (units.any((unit) => unit.unitCode == normalized)) return normalized;
    final preferred = kind == 'weight' ? 'kg' : baseUnit;
    return units.any((unit) => unit.unitCode == preferred)
        ? preferred
        : units.first.unitCode;
  }

  void _repairSelections() {
    primary = _safeUnit(primary);
    defaultSale = _safeUnit(defaultSale);
    purchaseUnit = _safeUnit(purchaseUnit);
    saleUnit = _safeUnit(saleUnit);
    openingUnit = _safeUnit(openingUnit);
    minimumUnit = _safeUnit(minimumUnit);
  }

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
      final existingUnits = data.units.isEmpty
          ? <UnitConversion>[
              UnitConversion(
                unitCode: p.baseUnit,
                baseUnit: p.baseUnit,
                numerator: 1,
                denominator: 1,
              ),
            ]
          : data.units;
      units = _normalizeUnits(
        existingUnits,
        p.baseUnit.trim().toLowerCase(),
        p.measurementKind,
      );
      primary = p.primaryUnit;
      minimumUnit = p.primaryUnit;
      defaultSale = p.defaultSaleUnit;
      purchaseUnit = data.purchasePrice?.conversion.unitCode ?? primary;
      saleUnit = data.salePrice?.conversion.unitCode ?? defaultSale;
      _repairSelections();
      final alertUnit = units.firstWhere(
        (unit) => unit.unitCode == minimumUnit,
      );
      minimum.text = Quantity.format(
        ScaledInteger.roundRatio(
          BigInt.from(p.minimumStockScaled) *
              BigInt.from(alertUnit.denominator),
          BigInt.from(alertUnit.numerator),
        ),
      );
      if (data.purchasePrice != null) {
        purchase.text = Money.formatUnitPrice(
          data.purchasePrice!.amountTicks,
          data.purchasePrice!.currency,
        );
      }
      if (data.salePrice != null) {
        sale.text = Money.formatUnitPrice(
          data.salePrice!.amountTicks,
          data.salePrice!.currency,
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
      minimumUnit = value == 'weight' ? 'kg' : b;
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
    if (result != null && mounted) {
      setState(() {
        units = _normalizeUnits(result, baseUnit, kind);
        _repairSelections();
      });
    }
  }

  Future<void> chooseUnit(String value, ValueChanged<String> changed) async {
    if (units.any((unit) => unit.unitCode == value)) {
      setState(() => changed(value));
      return;
    }
    final kg = kind == 'weight';
    var enteredFactor = '';
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set up $value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kg
                  ? '1 ${_title(value)} contains how many Kg?'
                  : 'How many pieces are in 1 ${_title(value)}?',
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (text) => enteredFactor = text,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: kg ? 'e.g. 50' : 'e.g. 12',
                suffixText: kg ? 'Kg' : 'pieces',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredFactor),
            child: const Text('Save unit'),
          ),
        ],
      ),
    );
    if (answer == null || !mounted) return;
    try {
      final conversion = UnitConversionService.define(
        unit: value,
        baseUnit: baseUnit,
        factor: answer,
        factorInKg: kg,
      );
      setState(() {
        units = _normalizeUnits([...units, conversion], baseUnit, kind);
        changed(value);
      });
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    }
  }

  String _title(String unit) =>
      unit.isEmpty ? unit : unit[0].toUpperCase() + unit.substring(1);

  Widget compactField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => TextField(
    controller: controller,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );

  List<String> _unitOptions() {
    final builtIns = kind == 'weight'
        ? const ['kg', 'gram', 'bag', 'sack', 'maund']
        : const ['piece'];
    final options = <String>{};
    for (final code in [...builtIns, ...units.map((unit) => unit.unitCode)]) {
      final normalized = code.trim().toLowerCase();
      if (normalized.isNotEmpty) options.add(normalized);
    }
    return options.toList();
  }

  Widget unitDropdown(
    String field,
    String value,
    ValueChanged<String> changed,
  ) {
    final options = _unitOptions();
    final requested = value.trim().toLowerCase();
    final selected = options.contains(requested)
        ? requested
        : (options.contains(kind == 'weight' ? 'kg' : baseUnit)
              ? (kind == 'weight' ? 'kg' : baseUnit)
              : options.first);
    return DropdownButtonFormField<String>(
      key: ValueKey('compact-unit:$field:$selected:$kind'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unit',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: options
          .map(
            (unit) => DropdownMenuItem(
              key: ValueKey('unit-option:$field:$unit'),
              value: unit,
              child: Text(_title(unit)),
            ),
          )
          .toList(),
      onChanged: busy
          ? null
          : (unit) {
              if (unit != null) chooseUnit(unit, changed);
            },
    );
  }

  Widget amountUnitRow(
    TextEditingController amount,
    String label,
    String unit,
    ValueChanged<String> changed,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 3, child: compactField(amount, label, numeric: true)),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: unitDropdown(label, unit, changed)),
    ],
  );

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final currency =
          ref.read(sessionProvider).asData?.value.shop?.currency ??
          Currency.pkr;
      final repository = await ref.read(productRepositoryProvider.future);
      final minimumConversion = units.singleWhere(
        (u) => u.unitCode == minimumUnit,
      );
      final minimumBase = minimum.text.trim().isEmpty
          ? '0'
          : Quantity.format(
              ScaledInteger.roundRatio(
                BigInt.from(Quantity.parse(minimum.text)) *
                    BigInt.from(minimumConversion.numerator),
                BigInt.from(minimumConversion.denominator),
              ),
            );
      var openingTotal = openingValue.text;
      if (openingTotal.trim().isEmpty &&
          openingQty.text.trim().isNotEmpty &&
          purchase.text.trim().isNotEmpty) {
        final quantity = UnitConversionService.snapshot(
          openingQty.text,
          units.singleWhere((u) => u.unitCode == openingUnit),
        );
        final minor = UnitConversionService.priceTotal(
          priceTicks: Money.parseUnitPrice(purchase.text, currency),
          pricingConversion: units.singleWhere(
            (u) => u.unitCode == purchaseUnit,
          ),
          quantity: quantity,
        );
        openingTotal = Money.format(minor, currency);
      }
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
          minimumStock: minimumBase,
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
                totalValue: openingTotal,
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
              padding: const EdgeInsets.all(16),
              children: [
                compactField(name, 'Product name'),
                const SizedBox(height: 10),
                if (widget.initial == null)
                  DropdownButtonFormField<String>(
                    key: ValueKey('measurement:$kind'),
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Measurement type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'weight', child: Text('Weight')),
                      DropdownMenuItem(value: 'custom', child: Text('Pieces')),
                    ],
                    onChanged: (v) => changeKind(v!),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Measurement type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Text(kind == 'weight' ? 'Weight' : 'Pieces'),
                  ),
                const SizedBox(height: 10),
                amountUnitRow(
                  purchase,
                  'Purchase price (${currency.code})',
                  purchaseUnit,
                  (v) {
                    purchaseUnit = v;
                  },
                ),
                const SizedBox(height: 10),
                amountUnitRow(sale, 'Sale price (${currency.code})', saleUnit, (
                  v,
                ) {
                  saleUnit = v;
                }),
                const SizedBox(height: 10),
                if (widget.initial == null) ...[
                  amountUnitRow(
                    openingQty,
                    'Opening stock (optional)',
                    openingUnit,
                    (v) {
                      openingUnit = v;
                    },
                  ),
                ] else ...[
                  amountUnitRow(
                    minimum,
                    'Low stock alert (optional)',
                    minimumUnit,
                    (v) {
                      minimumUnit = v;
                    },
                  ),
                ],
                if (widget.initial == null) ...[
                  const SizedBox(height: 10),
                  amountUnitRow(
                    minimum,
                    'Low stock alert (optional)',
                    minimumUnit,
                    (v) {
                      minimumUnit = v;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: advanced,
                  onExpansionChanged: (value) =>
                      setState(() => advanced = value),
                  title: const Text('Advanced options'),
                  children: [
                    EntryField(sku, 'SKU / code (optional)'),
                    EntryField(description, 'Description (optional)', lines: 2),
                    if (widget.initial == null)
                      EntryField(
                        openingValue,
                        'Opening value override (${currency.code}, optional)',
                        numeric: true,
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: configureUnits,
                        icon: const Icon(Icons.straighten),
                        label: const Text('Custom unit conversions'),
                      ),
                    ),
                  ],
                ),
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
