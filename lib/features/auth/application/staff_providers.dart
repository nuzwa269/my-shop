import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../data/local_staff_repository.dart';
import 'session_provider.dart';

final staffRepositoryProvider = FutureProvider(
  (ref) async => LocalStaffRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
    ref.watch(passwordHasherProvider),
  ),
);
final staffProvider = FutureProvider((ref) async {
  ref.watch(sessionProvider);
  return (await ref.watch(staffRepositoryProvider.future)).list();
});
