import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../services/id_service.dart';
import '../../../shared/widgets/form_support.dart';
import '../../trade/application/trade_providers.dart';
import '../../trade/domain/trade.dart';
import '../../trade/presentation/trade_widgets.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Customer khata'),
            Tab(text: 'Supplier khata'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              for (final kind in [PartyKind.customer, PartyKind.supplier])
                _KhataList(kind),
            ],
          ),
        ),
      ],
    ),
  );
}

class _KhataList extends ConsumerStatefulWidget {
  const _KhataList(this.kind);
  final PartyKind kind;
  @override
  ConsumerState<_KhataList> createState() => _KhataListState();
}

class _KhataListState extends ConsumerState<_KhataList> {
  String search = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            labelText: 'Search ${widget.kind.label.toLowerCase()}',
          ),
          onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
        ),
      ),
      Expanded(
        child: AsyncPanel(
          value: ref.watch(partiesProvider(widget.kind)),
          retry: () => ref.invalidate(partiesProvider(widget.kind)),
          data: (rows) {
            final items = rows
                .where(
                  (p) => (p['name'] as String).toLowerCase().contains(search),
                )
                .toList();
            if (items.isEmpty) {
              return const Center(child: Text('No contacts found.'));
            }
            return ListView(
              children: [
                for (final p in items)
                  ListTile(
                    title: Text(p['name'] as String),
                    subtitle: Text(
                      p['status'] == 'active'
                          ? 'View account'
                          : 'Inactive contact • account retained',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            KhataScreen(widget.kind, p['id'] as String),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class KhataScreen extends ConsumerWidget {
  const KhataScreen(this.kind, this.id, {super.key});
  final PartyKind kind;
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (kind: kind, id: id);
    return Scaffold(
      appBar: AppBar(
        title: Text('${kind.label} khata'),
        actions: [
          IconButton(
            tooltip: 'Refresh khata',
            onPressed: () => ref.invalidate(khataProvider(key)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncPanel(
        value: ref.watch(khataProvider(key)),
        retry: () => ref.invalidate(khataProvider(key)),
        data: (accounts) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              accounts.first.party['name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              kind == PartyKind.customer
                  ? 'Positive balance: customer owes the shop.'
                  : 'Positive balance: shop owes the supplier.',
            ),
            const Text(
              'Payments reduce the account balance. Original receipts remain unchanged.',
            ),
            for (final account in accounts) ...[
              const Divider(height: 32),
              Text(
                'Balance: ${moneyText(account.balance, account.currency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (account.balance > 0 && account.party['is_walk_in'] != 1)
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _PaymentScreen(kind, id, account),
                    ),
                  ),
                  child: Text(
                    kind == PartyKind.customer
                        ? 'Receive payment'
                        : 'Pay supplier',
                  ),
                ),
              if (account.entries.isEmpty) const Text('No posted entries yet.'),
              for (final row in account.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['entry_kind']} • ${dateText(row['occurred_at'] as int)}',
                        ),
                        Text(
                          'Change: ${moneyText(row['amount_delta_minor'] as int, account.currency)}',
                        ),
                        Text(
                          'Balance after entry: ${moneyText(row['running_balance'] as int, account.currency)}',
                        ),
                        if (row['note'] != null) Text(row['note'] as String),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentScreen extends ConsumerStatefulWidget {
  const _PaymentScreen(this.kind, this.id, this.account);
  final PartyKind kind;
  final String id;
  final KhataAccount account;
  @override
  ConsumerState<_PaymentScreen> createState() => _PaymentState();
}

class _PaymentState extends ConsumerState<_PaymentScreen> {
  final amount = TextEditingController(), note = TextEditingController();
  final requestId = IdService.newId();
  DateTime date = DateTime.now();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
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
        'Record cash payment?',
        'This posts an immutable payment and khata entry.',
      )) {
        return;
      }
      await (await ref.read(tradeRepositoryProvider.future)).settle(
        widget.kind,
        widget.id,
        currency: widget.account.currency,
        amountText: amount.text,
        expectedBalance: widget.account.balance,
        occurredAt: date.millisecondsSinceEpoch,
        requestId: requestId,
        note: note.text,
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
      appBar: AppBar(title: const Text('Account payment')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Outstanding: ${moneyText(widget.account.balance, widget.account.currency)}',
            ),
            EntryField(amount, 'Payment amount', numeric: true),
            TextButton(
              onPressed: () => amount.text = Money.format(
                widget.account.balance,
                widget.account.currency,
              ),
              child: const Text('Full balance'),
            ),
            DateField(value: date, onChanged: (v) => setState(() => date = v)),
            EntryField(note, 'Payment note (optional)'),
            ErrorNotice(error),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Record payment'),
            ),
          ],
        ),
      ),
    ),
  );
}
