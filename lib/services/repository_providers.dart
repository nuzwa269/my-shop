import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../features/auth/data/local_auth_repository.dart';
import '../features/auth/data/password_hasher.dart';
import '../features/auth/data/session_vault.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/password_hasher.dart';
import '../features/settings/data/local_shop_repository.dart';
import '../features/settings/domain/shop_setup.dart';
import '../features/products/data/local_product_repository.dart';
import '../features/products/domain/product.dart';

final passwordHasherProvider = Provider<PasswordHasher>(
  (ref) => const Pbkdf2PasswordHasher(),
);
final sessionVaultProvider = Provider<SessionVault>(
  (ref) => const SecureSessionVault(),
);
final authRepositoryProvider = FutureProvider<AuthRepository>(
  (ref) async => LocalAuthRepository(
    await ref.watch(databaseProvider.future),
    ref.watch(passwordHasherProvider),
    ref.watch(sessionVaultProvider),
  ),
);
final shopRepositoryProvider = FutureProvider<ShopRepository>(
  (ref) async => LocalShopRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
    ref.watch(passwordHasherProvider),
  ),
);
final productRepositoryProvider = FutureProvider<ProductRepository>(
  (ref) async => LocalProductRepository(
    await ref.watch(databaseProvider.future),
    await ref.watch(authRepositoryProvider.future),
  ),
);
