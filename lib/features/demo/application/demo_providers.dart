import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../../trade/application/trade_providers.dart';
import '../data/local_demo_repository.dart';

final demoRepositoryProvider = FutureProvider(
  (ref) async => LocalDemoRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);
final demoAvailabilityProvider = FutureProvider((ref) async {
  ref.watch(sessionProvider);
  ref.watch(tradeRevisionProvider);
  return (await ref.watch(demoRepositoryProvider.future)).availability();
});
