import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/form_support.dart';
import '../application/trade_providers.dart';
import '../domain/trade.dart';
import 'trade_widgets.dart';

class PartyListScreen extends ConsumerStatefulWidget {
  const PartyListScreen(this.kind, {super.key});
  final PartyKind kind;
  @override
  ConsumerState<PartyListScreen> createState() => _PartyListState();
}

class _PartyListState extends ConsumerState<PartyListScreen> {
  String search = '';
  bool showInactive = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Search ${widget.kind.label.toLowerCase()}s',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
            ),
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Include inactive'),
                  selected: showInactive,
                  onSelected: (v) => setState(() => showInactive = v),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PartyEditor(widget.kind),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text('Add ${widget.kind.label.toLowerCase()}'),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: AsyncPanel(
          value: ref.watch(partiesProvider(widget.kind)),
          retry: () => ref.invalidate(partiesProvider(widget.kind)),
          data: (rows) {
            final items = rows
                .where(
                  (r) =>
                      (showInactive || r['status'] == 'active') &&
                      (r['name'] as String).toLowerCase().contains(search),
                )
                .toList();
            if (items.isEmpty) {
              return const Center(
                child: Text('No contacts found. Add one to get started.'),
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final row = items[i];
                return ListTile(
                  leading: Icon(
                    widget.kind == PartyKind.supplier
                        ? Icons.local_shipping_outlined
                        : Icons.person_outline,
                  ),
                  title: Text(row['name'] as String),
                  subtitle: Text(
                    [
                      row['phone'],
                      row['status'] == 'archived' ? 'Inactive' : null,
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PartyDetail(widget.kind, row['id'] as String),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class PartyDetail extends ConsumerWidget {
  const PartyDetail(this.kind, this.id, {super.key});
  final PartyKind kind;
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text('${kind.label} details')),
    body: AsyncPanel(
      value: ref.watch(partiesProvider(kind)),
      retry: () => ref.invalidate(partiesProvider(kind)),
      data: (rows) {
        final row = rows.where((r) => r['id'] == id).firstOrNull;
        if (row == null) return const Center(child: Text('Contact not found.'));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              row['name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(row['status'] == 'active' ? 'Active' : 'Inactive'),
            for (final field in ['phone', 'address', 'note'])
              if (row[field] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(row[field] as String),
                ),
            const SizedBox(height: 24),
            if (row['is_walk_in'] != 1)
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PartyEditor(kind, row: row),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit contact'),
              ),
          ],
        );
      },
    ),
  );
}

class PartyEditor extends ConsumerStatefulWidget {
  const PartyEditor(this.kind, {this.row, super.key});
  final PartyKind kind;
  final DataRow? row;
  @override
  ConsumerState<PartyEditor> createState() => _PartyEditorState();
}

class _PartyEditorState extends ConsumerState<PartyEditor> {
  late final name = TextEditingController(text: widget.row?['name'] as String?);
  late final phone = TextEditingController(
    text: widget.row?['phone'] as String?,
  );
  late final address = TextEditingController(
    text: widget.row?['address'] as String?,
  );
  late final note = TextEditingController(text: widget.row?['note'] as String?);
  late bool active = widget.row?['status'] != 'archived';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [name, phone, address, note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!active &&
        widget.row?['status'] == 'active' &&
        !await confirmAction(
          context,
          'Deactivate contact?',
          'Existing transactions and balances will be retained.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (await ref.read(tradeRepositoryProvider.future)).saveParty(
        widget.kind,
        name: name.text,
        phone: phone.text,
        address: address.text,
        note: note.text,
        active: active,
        id: widget.row?['id'] as String?,
        revision: widget.row?['revision'] as int?,
      );
      tradeChanged(ref);
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
          '${widget.row == null ? 'Add' : 'Edit'} ${widget.kind.label.toLowerCase()}',
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              EntryField(name, 'Name'),
              EntryField(phone, 'Phone (optional)'),
              EntryField(address, 'Address (optional)', lines: 2),
              EntryField(note, 'Notes (optional)', lines: 2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
              ErrorNotice(error),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save contact'),
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
  );
}
