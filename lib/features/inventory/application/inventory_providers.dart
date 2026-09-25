import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product.dart';
import '../data/local_inventory_repository.dart';
import '../domain/inventory.dart';

final inventoryRepositoryProvider = FutureProvider<InventoryRepository>(
  (ref) async => LocalInventoryRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);

final inventoryListProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(sessionProvider);
  // Product/opening changes and trade posting already invalidate this dependency.
  ref.watch(productListProvider((search: '', active: true)));
  return (await ref.watch(inventoryRepositoryProvider.future)).list();
});

final inventoryDetailsProvider =
    FutureProvider.family<InventoryDetails, String>((ref, id) async {
      ref.watch(inventoryListProvider);
      return (await ref.watch(inventoryRepositoryProvider.future)).details(id);
    });
