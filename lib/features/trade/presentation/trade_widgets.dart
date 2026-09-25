import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/form_support.dart';

String moneyText(int value, Currency c) =>
    '${c.code} ${Money.format(value, c)}';
String dateText(int value) {
  final d = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    required this.value,
    required this.data,
    required this.retry,
    super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(actionError(e), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class DateField extends StatelessWidget {
  const DateField({required this.value, required this.onChanged, super.key});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Date'),
    subtitle: Text(dateText(value.millisecondsSinceEpoch)),
    trailing: const Icon(Icons.calendar_month),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (date != null) onChanged(date);
    },
  );
}

class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.value, {this.emphasis = false, super.key});
  final String label, value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 20,
      runSpacing: 4,
      children: [
        Text(label),
        Text(
          value,
          style: emphasis ? Theme.of(context).textTheme.titleMedium : null,
        ),
      ],
    ),
  );
}
