import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../../trade/application/trade_providers.dart';
import '../data/local_expense_repository.dart';

final expenseRepositoryProvider = FutureProvider(
  (ref) async => LocalExpenseRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);
final expensesProvider = FutureProvider((ref) async {
  ref.watch(sessionProvider);
  ref.watch(tradeRevisionProvider);
  return (await ref.watch(expenseRepositoryProvider.future)).list();
});
