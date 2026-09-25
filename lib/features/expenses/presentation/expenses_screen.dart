import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../services/id_service.dart';
import '../../../shared/widgets/form_support.dart';
import '../../trade/presentation/trade_widgets.dart';
import '../../trade/application/trade_providers.dart';
import '../application/expense_providers.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ExpenseEditor()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Record expense'),
        ),
      ),
      Expanded(
        child: AsyncPanel(
          value: ref.watch(expensesProvider),
          retry: () => ref.invalidate(expensesProvider),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('No expenses yet.'))
              : ListView(
                  children: [
                    for (final row in rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['category'] as String,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(row['description'] as String),
                              Text(dateText(row['occurred_at'] as int)),
                              Text(
                                moneyText(
                                  row['total_minor'] as int,
                                  Currency(
                                    row['currency_code'] as String,
                                    minorDigits:
                                        row['currency_minor_digits'] as int,
                                  ),
                                ),
                              ),
                              const Text('Paid in cash'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    ],
  );
}

class ExpenseEditor extends ConsumerStatefulWidget {
  const ExpenseEditor({super.key});
  @override
  ConsumerState<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<ExpenseEditor> {
  final category = TextEditingController(),
      description = TextEditingController(),
      amount = TextEditingController();
  final requestId = IdService.newId();
  DateTime date = DateTime.now();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    category.dispose();
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      if (!await confirmAction(
        context,
        'Post expense?',
        'This records an immutable cash expense and payment.',
      )) {
        return;
      }
      await (await ref.read(expenseRepositoryProvider.future)).post(
        category: category.text,
        description: description.text,
        amount: amount.text,
        occurredAt: date.millisecondsSinceEpoch,
        requestId: requestId,
      );
      tradeChanged(ref);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = actionError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cash expense')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            EntryField(
              category,
              'Category',
              hint: 'Rent, transport, utilities...',
            ),
            EntryField(description, 'Description'),
            EntryField(amount, 'Amount', numeric: true),
            DateField(value: date, onChanged: (v) => setState(() => date = v)),
            ErrorNotice(error),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Post expense'),
            ),
          ],
        ),
      ),
    ),
  );
}
