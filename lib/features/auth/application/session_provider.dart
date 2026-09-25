import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/repository_providers.dart';
import '../../settings/domain/shop_setup.dart';
import '../domain/auth_repository.dart';

class AppSession {
  const AppSession({required this.configured, this.owner, this.shop});
  final bool configured;
  final OwnerSession? owner;
  final ShopProfile? shop;
}

class SessionController extends AsyncNotifier<AppSession> {
  Timer? _expiry;
  @override
  Future<AppSession> build() async {
    ref.onDispose(() => _expiry?.cancel());
    final shops = await ref.watch(shopRepositoryProvider.future);
    if (!await shops.isConfigured()) return const AppSession(configured: false);
    final auth = await ref.watch(authRepositoryProvider.future);
    final owner = await auth.restore();
    final shop = owner == null ? null : await shops.current();
    _schedule(owner);
    return AppSession(configured: true, owner: owner, shop: shop);
  }

  void _schedule(OwnerSession? owner) {
    _expiry?.cancel();
    if (owner != null) {
      final wait =
          owner.expiresAt - DateTime.now().toUtc().millisecondsSinceEpoch;
      _expiry = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () {
        state = const AsyncData(AppSession(configured: true));
      });
    }
  }

  Future<void> setup(ShopSetupInput input) async {
    await (await ref.read(shopRepositoryProvider.future)).setup(input);
    state = const AsyncData(AppSession(configured: true));
  }

  Future<void> login(String username, String password) async {
    final owner = await (await ref.read(authRepositoryProvider.future))
        .login(username, password);
    final shop = await (await ref.read(shopRepositoryProvider.future))
        .current();
    _schedule(owner);
    state = AsyncData(AppSession(configured: true, owner: owner, shop: shop));
  }

  Future<void> logout() async {
    try {
      await (await ref.read(authRepositoryProvider.future)).logout();
    } finally {
      _expiry?.cancel();
      state = const AsyncData(AppSession(configured: true));
    }
  }

  Future<void> refresh() async {
    if (state.asData?.value.configured != true) return;
    final auth = await ref.read(authRepositoryProvider.future);
    final owner = await auth.restore();
    _schedule(owner);
    final shop = owner == null
        ? null
        : await (await ref.read(shopRepositoryProvider.future)).current();
    state = AsyncData(AppSession(configured: true, owner: owner, shop: shop));
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AppSession>(
  SessionController.new,
);
