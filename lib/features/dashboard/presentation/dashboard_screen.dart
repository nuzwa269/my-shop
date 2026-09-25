import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_provider.dart';
import '../../trade/presentation/trade_widgets.dart';
import '../application/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider).asData?.value;
    return AsyncPanel(
      value: ref.watch(dashboardProvider),
      retry: () => ref.invalidate(dashboardProvider),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            state?.shop?.name ?? '',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text('Signed in as ${state?.owner?.fullName ?? ""}'),
          Text(state?.shop?.category ?? ''),
          if (summary.demo)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'DEMO DATA • This shop contains sample transactions.',
                ),
              ),
            ),
          Text(summary.cashier ? 'Cashier access' : 'Owner access'),
          TextButton.icon(
            onPressed: () => ref.invalidate(dashboardProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh dashboard'),
          ),
          if (!summary.cashier) ...[
            Text(
              'Active products: ${summary.activeProducts}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Low stock: ${summary.lowStock} • Out of stock: ${summary.outOfStock}',
            ),
          ],
          const SizedBox(height: 12),
          if (!summary.cashier)
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/products'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Manage products'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/sales'),
            child: const Text('Open sales'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/customers'),
            child: const Text('Customers / khata'),
          ),
          if (!summary.cashier)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in {
                  '/purchases': 'Purchases',
                  '/suppliers': 'Suppliers',
                  '/inventory': 'Inventory',
                  '/ledger': 'Khata / Ledger',
                  '/expenses': 'Expenses',
                  '/settings': 'Settings',
                }.entries)
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed(link.key),
                    child: Text(link.value),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text(
            'Today: ${summary.date.year}-${summary.date.month.toString().padLeft(2, '0')}-${summary.date.day.toString().padLeft(2, '0')} (device local time)',
          ),
          for (final money in summary.money)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmountRow(
                      summary.cashier ? 'Your sales today' : 'Sales today',
                      moneyText(money.sales, money.currency),
                    ),
                    if (!summary.cashier) ...[
                      AmountRow(
                        'Purchases today',
                        moneyText(money.purchases, money.currency),
                      ),
                      AmountRow(
                        'Expenses today',
                        moneyText(money.expenses, money.currency),
                      ),
                      const Divider(),
                      AmountRow(
                        'Customer balance (all time)',
                        moneyText(money.receivable, money.currency),
                      ),
                      AmountRow(
                        'Supplier balance (all time)',
                        moneyText(money.payable, money.currency),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const Text(
            'Posted totals only. Sales are after discounts. These figures are not cash-on-hand or profit.',
          ),
        ],
      ),
    );
  }
}
