import 'package:flutter/material.dart';

import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';
import '../../../shared/widgets/form_support.dart';

class UnitConfigurationScreen extends StatefulWidget {
  const UnitConfigurationScreen({
    required this.units,
    required this.baseUnit,
    required this.requiredUnits,
    super.key,
  });
  final List<UnitConversion> units;
  final String baseUnit;
  final Set<String> requiredUnits;
  @override
  State<UnitConfigurationScreen> createState() =>
      _UnitConfigurationScreenState();
}

class _UnitConfigurationScreenState extends State<UnitConfigurationScreen> {
  late final List<UnitConversion> units = List.of(widget.units);
  Future<void> edit([UnitConversion? original]) async {
    final result = await showDialog<UnitConversion>(
      context: context,
      builder: (context) =>
          _UnitDialog(baseUnit: widget.baseUnit, original: original),
    );
    if (result == null || !mounted) return;
    final existing = units.indexWhere((u) => u.unitCode == result.unitCode);
    if (original == null && existing >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This unit is already defined.')),
      );
      return;
    }
    setState(() {
      if (existing >= 0) {
        units[existing] = result;
      } else {
        units.add(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product units')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Base unit: ${widget.baseUnit}'),
          const Text(
            'Define the size of one unit. Bag, sack and maund have no assumed weight.',
          ),
          const SizedBox(height: 16),
          for (final unit in units)
            Card(
              child: ListTile(
                title: Text(unit.unitCode),
                subtitle: Text(
                  '1 ${unit.unitCode} = ${unit.displayFactor} ${unit.baseUnit}',
                ),
                trailing: Wrap(
                  children: [
                    if (unit.unitCode != widget.baseUnit &&
                        unit.unitCode != 'kg')
                      IconButton(
                        tooltip: 'Edit ${unit.unitCode}',
                        onPressed: () => edit(unit),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (!widget.requiredUnits.contains(unit.unitCode) &&
                        unit.unitCode != widget.baseUnit)
                      IconButton(
                        tooltip: 'Remove ${unit.unitCode}',
                        onPressed: () => setState(() => units.remove(unit)),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add unit'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Saving the product creates new price snapshots if a pricing factor changed. Historical prices and opening stock keep their original factors.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(units),
            child: const Text('Use these units'),
          ),
        ],
      ),
    ),
  );
}

class _UnitDialog extends StatefulWidget {
  const _UnitDialog({required this.baseUnit, this.original});
  final String baseUnit;
  final UnitConversion? original;
  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  late final code = TextEditingController(
    text: widget.original?.unitCode ?? '',
  );
  final factor = TextEditingController();
  bool inKg = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    factor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.original == null ? 'Add unit' : 'Edit unit conversion'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EntryField(
            code,
            'Unit code',
            enabled: widget.original == null,
            hint: 'bag, sack, maund, piece, or custom',
          ),
          EntryField(
            factor,
            'One unit equals',
            numeric: true,
            hint: 'Enter the new conversion factor',
          ),
          if (widget.baseUnit == 'gram')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                inKg ? 'Factor entered in kg' : 'Factor entered in grams',
              ),
              value: inKg,
              onChanged: (v) => setState(() => inKg = v),
            ),
          if (widget.baseUnit != 'gram')
            Text('Factor is in ${widget.baseUnit}.'),
          ErrorNotice(error),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          try {
            Navigator.pop(
              context,
              UnitConversionService.define(
                unit: code.text,
                baseUnit: widget.baseUnit,
                factor: factor.text,
                factorInKg: inKg,
              ),
            );
          } catch (e) {
            setState(() => error = actionError(e));
          }
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
