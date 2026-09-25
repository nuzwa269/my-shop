import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/form_support.dart';
import '../../trade/presentation/trade_widgets.dart';
import '../application/staff_providers.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Cashier / staff access')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Cashiers can sell, view receipts, manage customers and receive customer payments. Purchases, suppliers, expenses, inventory and settings stay owner-only.',
              ),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _StaffEditor()),
                ),
                child: const Text('Add cashier'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncPanel(
            value: ref.watch(staffProvider),
            retry: () => ref.invalidate(staffProvider),
            data: (rows) => rows.isEmpty
                ? const Center(child: Text('No staff accounts yet.'))
                : ListView(children: [for (final row in rows) _StaffTile(row)]),
          ),
        ),
      ],
    ),
  );
}

class _StaffTile extends ConsumerStatefulWidget {
  const _StaffTile(this.row);
  final Map<String, Object?> row;
  @override
  ConsumerState<_StaffTile> createState() => _StaffTileState();
}

class _StaffTileState extends ConsumerState<_StaffTile> {
  bool busy = false;
  Future<void> toggle() async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      final active = widget.row['status'] != 'active';
      if (!await confirmAction(
        context,
        active ? 'Reactivate cashier?' : 'Deactivate cashier?',
        'Existing transactions are retained. Current sessions will be revoked.',
      )) {
        return;
      }
      await (await ref.read(staffRepositoryProvider.future)).setActive(
        widget.row['id'] as String,
        active,
        widget.row['revision'] as int,
      );
      ref.invalidate(staffProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(actionError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.row['display_name'] as String),
    subtitle: Text('${widget.row['username']} • ${widget.row['status']}'),
    trailing: TextButton(
      onPressed: busy ? null : toggle,
      child: Text(
        widget.row['status'] == 'active' ? 'Deactivate' : 'Reactivate',
      ),
    ),
  );
}

class _StaffEditor extends ConsumerStatefulWidget {
  const _StaffEditor();
  @override
  ConsumerState<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends ConsumerState<_StaffEditor> {
  final name = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await (await ref.read(staffRepositoryProvider.future)).create(
        name: name.text,
        username: username.text,
        password: password.text,
      );
      password.clear();
      ref.invalidate(staffProvider);
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
      appBar: AppBar(title: const Text('Add cashier')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            EntryField(name, 'Staff name'),
            EntryField(username, 'Staff username'),
            EntryField(password, 'Staff password or PIN', obscure: true),
            const Text(
              'Use a 6–12 digit PIN or a password of 12–128 characters. Share it privately with the staff member.',
            ),
            ErrorNotice(error),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Create cashier'),
            ),
          ],
        ),
      ),
    ),
  );
}
