import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../domain/product.dart';

final productListProvider =
    FutureProvider.family<List<Product>, ({String search, bool? active})>((
      ref,
      filter,
    ) async {
      final owner = ref.watch(sessionProvider).asData?.value.owner;
      if (owner == null) return [];
      return (await ref.watch(productRepositoryProvider.future))
          .list(search: filter.search, active: filter.active);
    });
final productDetailsProvider = FutureProvider.family<ProductDetails, String>((
  ref,
  id,
) async {
  ref.watch(sessionProvider);
  return (await ref.watch(productRepositoryProvider.future)).details(id);
});
