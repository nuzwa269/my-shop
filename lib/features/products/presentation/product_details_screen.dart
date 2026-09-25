import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/numeric/scaled_integer.dart';
import '../../../core/units/quantity.dart';
import '../../../services/repository_providers.dart';
import '../../../shared/widgets/form_support.dart';
import '../../auth/application/session_provider.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_editor_screen.dart';
import 'opening_stock_screen.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({required this.id, super.key});
  final String id;
  String priceLabel(PriceSnapshot? price) {
    if (price == null) return 'Not configured';
    final raw = Money.formatUnitPrice(price.amountTicks, price.currency);
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final amount = parts.length == 1 ? whole : '$whole.${parts.last}';
    return '${price.currency.code} $amount per ${price.conversion.unitCode}';
  }

  String stockQuantity(
    Product product,
    List<UnitConversion> units,
    int scaled,
  ) {
    UnitConversion? displayConversion;
    for (final conversion in units) {
      if (conversion.unitCode == product.primaryUnit) {
        displayConversion = conversion;
        break;
      }
    }
    if (displayConversion == null) {
      for (final conversion in units) {
        if (conversion.unitCode == product.baseUnit) {
          displayConversion = conversion;
          break;
        }
      }
    }
    if (displayConversion == null) {
      return '${Quantity.formatDisplay(scaled)} ${product.baseUnit}';
    }
    final displayScaled = ScaledInteger.roundRatio(
      BigInt.from(scaled) * BigInt.from(displayConversion.denominator),
      BigInt.from(displayConversion.numerator),
    );
    return '${Quantity.formatDisplay(displayScaled)} ${displayConversion.unitCode}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(productDetailsProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: SafeArea(
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(actionError(e)),
            ),
          ),
          data: (details) {
            final p = details.product;
            final currency =
                ref.watch(sessionProvider).asData?.value.shop?.currency ??
                Currency.pkr;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
                Text(p.active ? 'Active' : 'Inactive'),
                if (p.sku != null) Text('SKU: ${p.sku}'),
                if (p.description != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(p.description!),
                  ),
                const Divider(height: 32),
                Text(
                  'Stock: ${stockQuantity(p, details.units, p.stockScaled)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Minimum alert: ${stockQuantity(p, details.units, p.minimumStockScaled)}',
                ),
                if (p.stockScaled < p.minimumStockScaled)
                  const Text('Below minimum stock'),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Purchase price'),
                  subtitle: Text(priceLabel(details.purchasePrice)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sale price'),
                  subtitle: Text(priceLabel(details.salePrice)),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<String>(
                          builder: (_) => ProductEditorScreen(initial: details),
                        ),
                      ),
                      child: const Text('Edit product'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<String>(
                          builder: (_) => ProductEditorScreen(
                            initial: details,
                            configureUnitsFirst: true,
                          ),
                        ),
                      ),
                      child: const Text('Configure units'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              p.active
                                  ? 'Deactivate product?'
                                  : 'Reactivate product?',
                            ),
                            content: const Text(
                              'All product, price and stock history will be retained.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        try {
                          await (await ref.read(
                            productRepositoryProvider.future,
                          )).setActive(id, !p.active, p.revision);
                          ref.invalidate(productListProvider);
                          ref.invalidate(productDetailsProvider(id));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(actionError(e))),
                            );
                          }
                        }
                      },
                      child: Text(p.active ? 'Deactivate' : 'Reactivate'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  'Opening stock',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (details.opening case final opening?) ...[
                  Text(
                    '${Quantity.formatDisplay(opening.quantity.originalQuantityScaled)} ${opening.quantity.conversion.unitCode}',
                  ),
                  Text(
                    'Total opening value: ${opening.valueMinor == null ? "Not supplied" : "${currency.code} ${Money.format(opening.valueMinor!, currency)}"}',
                  ),
                  Text(
                    'Dated: ${DateTime.fromMillisecondsSinceEpoch(opening.occurredAt).toLocal()}',
                  ),
                ] else
                  const Text('No opening stock entered.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: !p.active || details.units.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OpeningStockScreen(details: details),
                          ),
                        ),
                  child: Text(
                    details.opening == null
                        ? 'Enter opening stock'
                        : 'Correct opening stock',
                  ),
                ),
                const Divider(height: 32),
                ExpansionTile(
                  title: const Text('Price history'),
                  children: [
                    for (final price in details.prices)
                      ListTile(
                        title: Text('${price.kind}: ${priceLabel(price)}'),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(price.createdAt)
                              .toLocal()
                              .toString(),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
