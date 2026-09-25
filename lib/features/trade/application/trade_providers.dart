import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_provider.dart';
import '../../../services/repository_providers.dart';
import '../../auth/application/session_provider.dart';
import '../../products/application/product_providers.dart';
import '../data/local_trade_repository.dart';
import '../domain/trade.dart';

final tradeRepositoryProvider = FutureProvider(
  (ref) async => LocalTradeRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);

class TradeRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final tradeRevisionProvider = NotifierProvider<TradeRevision, int>(
  TradeRevision.new,
);
void tradeChanged(WidgetRef ref) {
  ref.read(tradeRevisionProvider.notifier).changed();
  ref.invalidate(productListProvider);
  ref.invalidate(productDetailsProvider);
}

final partiesProvider = FutureProvider.family<List<DataRow>, PartyKind>((
  ref,
  kind,
) async {
  ref.watch(sessionProvider);
  ref.watch(tradeRevisionProvider);
  return (await ref.watch(tradeRepositoryProvider.future)).parties(kind);
});
final documentsProvider = FutureProvider.family<List<DataRow>, TradeKind>((
  ref,
  kind,
) async {
  ref.watch(sessionProvider);
  ref.watch(tradeRevisionProvider);
  return (await ref.watch(tradeRepositoryProvider.future)).documents(kind);
});
final documentProvider =
    FutureProvider.family<DataRow, ({TradeKind kind, String id})>((
      ref,
      key,
    ) async {
      ref.watch(sessionProvider);
      ref.watch(tradeRevisionProvider);
      return (await ref.watch(tradeRepositoryProvider.future))
          .document(key.kind, key.id);
    });
final catalogProvider = FutureProvider.family<List<CatalogItem>, TradeKind>((
  ref,
  kind,
) async {
  ref.watch(sessionProvider);
  ref.watch(tradeRevisionProvider);
  ref.watch(productListProvider((search: '', active: true)));
  return (await ref.watch(tradeRepositoryProvider.future)).catalog(kind);
});
