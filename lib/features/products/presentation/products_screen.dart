import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/form_support.dart';
import '../application/product_providers.dart';
import 'product_editor_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String search = '', filter = 'active';
  @override
  Widget build(BuildContext context) {
    final query = (
      search: search,
      active: filter == 'all' ? null : filter == 'active',
    );
    final products = ref.watch(productListProvider(query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search products or SKU',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: filter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All products'),
                        ),
                      ],
                      onChanged: (v) => setState(() => filter = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final id = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductEditorScreen(),
                        ),
                      );
                      if (id != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ProductDetailsScreen(id: id),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionError(e)),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(productListProvider(query)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Center(child: Text('No products found.'))
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productListProvider(query));
                      await ref.read(productListProvider(query).future);
                    },
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final p = items[index];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.sku ?? "No SKU"} · ${p.active ? "Active" : "Inactive"}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ProductDetailsScreen(id: p.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
