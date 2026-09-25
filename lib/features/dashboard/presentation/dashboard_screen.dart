import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_provider.dart';
import '../../products/application/product_providers.dart';
import '../../../shared/widgets/form_support.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider).asData?.value;
    final products = ref.watch(productListProvider((search: '', active: true)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          state?.shop?.name ?? '',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text('Signed in as ${state?.owner?.fullName ?? ""}'),
        Text(state?.shop?.category ?? ''),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: products.when(
              data: (items) => Text(
                'Active products: ${items.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              error: (e, _) => Text(actionError(e)),
              loading: () => const LinearProgressIndicator(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/products'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Manage products'),
        ),
        const SizedBox(height: 24),
        for (final title in ['Purchases', 'Sales', 'Khata / Ledger', 'Reports'])
          Card(
            child: ListTile(
              title: Text(title),
              subtitle: const Text('Available in a later phase'),
              trailing: const Icon(Icons.lock_outline),
            ),
          ),
      ],
    );
  }
}
