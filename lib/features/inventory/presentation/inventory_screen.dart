import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/units/quantity.dart';
import '../../../core/validation/validation.dart';
import '../../trade/presentation/trade_widgets.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String search = '';
  bool includeInactive = false;
  StockFilter filter = StockFilter.all;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search inventory or SKU',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => search = Validation.key(value)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in StockFilter.values)
                  ChoiceChip(
                    label: Text(switch (value) {
                      StockFilter.all => 'All stock',
                      StockFilter.low => 'Low stock',
                      StockFilter.out => 'Out of stock',
                    }),
                    selected: filter == value,
                    onSelected: (_) => setState(() => filter = value),
                  ),
                FilterChip(
                  label: const Text('Include inactive'),
                  selected: includeInactive,
                  onSelected: (value) =>
                      setState(() => includeInactive = value),
                ),
                IconButton(
                  tooltip: 'Refresh inventory',
                  onPressed: () => ref.invalidate(inventoryListProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: AsyncPanel(
          value: ref.watch(inventoryListProvider),
          retry: () => ref.invalidate(inventoryListProvider),
          data: (products) {
            final visible = products
                .where(
                  (p) =>
                      (includeInactive || p.active) &&
                      matchesStock(p, filter) &&
                      (Validation.key(p.name).contains(search) ||
                          (p.sku?.toLowerCase().contains(search) ?? false)),
                )
                .toList();
            if (visible.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No products match these inventory filters.'),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inventoryListProvider);
                await ref.read(inventoryListProvider.future);
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final p = visible[index];
                  return ListTile(
                    isThreeLine: true,
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.sku ?? "No SKU"} • ${p.active ? stockLabel(p) : "Inactive"}\n${Quantity.format(p.stockScaled)} ${p.baseUnit}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => InventoryDetailsScreen(p.id),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class InventoryDetailsScreen extends ConsumerWidget {
  const InventoryDetailsScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Stock movements'),
      actions: [
        IconButton(
          tooltip: 'Refresh stock movements',
          onPressed: () => ref.invalidate(inventoryDetailsProvider(id)),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AsyncPanel(
      value: ref.watch(inventoryDetailsProvider(id)),
      retry: () => ref.invalidate(inventoryDetailsProvider(id)),
      data: (details) {
        final p = details.product;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('${p.active ? "Active" : "Inactive"} • ${stockLabel(p)}'),
            const SizedBox(height: 16),
            Text('Available: ${Quantity.format(p.stockScaled)} ${p.baseUnit}'),
            Text(
              'Minimum: ${Quantity.format(p.minimumStockScaled)} ${p.baseUnit}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Stock is calculated from posted movements. Reversals remain in history. Quantities below retain the units used at entry.',
            ),
            const Divider(height: 32),
            if (details.movements.isEmpty)
              const Text('No posted stock movements yet.'),
            for (final movement in details.movements)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.reason.replaceAll('_', ' '),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(dateText(movement.occurredAt)),
                      Text(
                        '${movement.delta > 0 ? "+" : ""}${Quantity.format(movement.delta)} ${p.baseUnit}',
                      ),
                      Text(
                        'Entered: ${Quantity.format(movement.quantity.originalQuantityScaled)} ${movement.quantity.conversion.unitCode}',
                      ),
                      Text(movement.note),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
