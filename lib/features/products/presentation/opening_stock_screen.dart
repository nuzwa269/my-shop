import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
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
  final quantity = TextEditingController(),
      value = TextEditingController(),
      reason = TextEditingController();
  late String unit;
  DateTime occurred = DateTime.now();
  bool busy = false;
  String? error;
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
      final currency = ref.read(sessionProvider).asData!.value.shop!.currency;
      if (previous.valueMinor != null) {
        value.text = Money.format(previous.valueMinor!, currency);
      }
    } else {
      reason.text = 'Initial stock count';
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    value.dispose();
    reason.dispose();
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
          totalValue: value.text,
          reason: reason.text,
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
              if (widget.details.opening != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Enter the corrected total opening quantity, not today’s stock. Saving reverses the previous opening and records a replacement. Current unit factors apply.',
                  ),
                ),
              EntryField(quantity, 'Opening quantity', numeric: true),
              DropdownButtonFormField<String>(
                initialValue: unit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: widget.details.units
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.unitCode,
                        child: Text(u.unitCode),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => unit = v!),
              ),
              const SizedBox(height: 16),
              EntryField(
                value,
                'Total opening value (optional)',
                numeric: true,
                hint:
                    'Value of all opening stock; no costing method is assumed.',
              ),
              EntryField(reason, 'Reason / audit note'),
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
