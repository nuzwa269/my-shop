import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/form_support.dart';
import '../../trade/application/trade_providers.dart';
import '../../trade/presentation/trade_widgets.dart';
import '../application/demo_providers.dart';
import '../data/local_demo_repository.dart';

class DemoScreen extends ConsumerStatefulWidget {
  const DemoScreen({super.key});
  @override
  ConsumerState<DemoScreen> createState() => _DemoState();
}

class _DemoState extends ConsumerState<DemoScreen> {
  bool busy = false;
  String? error;
  Future<void> load() async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      if (!await confirmAction(
        context,
        'Load demo transactions?',
        'Adds two products, a supplier, a customer, purchase, sale, khata payments and an expense. These are retained sample records, not a temporary preview. Use only a dedicated demo shop.',
      )) {
        return;
      }
      await (await ref.read(demoRepositoryProvider.future)).load();
      tradeChanged(ref);
      ref.invalidate(demoAvailabilityProvider);
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
      appBar: AppBar(title: const Text('Optional demo data')),
      body: AsyncPanel(
        value: ref.watch(demoAvailabilityProvider),
        retry: () => ref.invalidate(demoAvailabilityProvider),
        data: (availability) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Demo data is never loaded automatically. Loading is allowed only before real products, contacts or transactions have been added.',
            ),
            const SizedBox(height: 16),
            Text(switch (availability) {
              DemoAvailability.ready => 'This shop is empty and eligible. Sample amounts use the configured shop currency. No staff credentials are seeded; create a cashier in Settings if needed.',
              DemoAvailability.loaded =>
                'Demo data is already loaded. It will not be duplicated.',
              DemoAvailability.existingData => 'This shop contains existing data. Demo loading is disabled; your records are preserved.',
            }),
            const SizedBox(height: 16),
            ErrorNotice(error),
            if (availability == DemoAvailability.ready)
              FilledButton(
                onPressed: busy ? null : load,
                child: Text(busy ? 'Loading...' : 'Load demo data'),
              ),
          ],
        ),
      ),
    ),
  );
}
