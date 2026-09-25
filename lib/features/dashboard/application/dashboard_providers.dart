import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permissions.dart';
import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../../products/application/product_providers.dart';
import '../../trade/application/trade_providers.dart';
import '../data/local_dashboard_repository.dart';

final dashboardRepositoryProvider = FutureProvider(
  (ref) async => LocalDashboardRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);
final dashboardProvider = FutureProvider((ref) async {
  final role = ref.watch(sessionProvider).asData?.value.owner?.role;
  ref.watch(tradeRevisionProvider);
  if (role == ShopRole.owner) {
    ref.watch(productListProvider((search: '', active: true)));
  }
  return (await ref.watch(dashboardRepositoryProvider.future)).summary();
});
