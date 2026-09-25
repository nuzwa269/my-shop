import '../../../core/permissions/permissions.dart';
import '../../../database/database_connection.dart';

class OwnerSession {
  const OwnerSession({
    required this.userId,
    required this.shopId,
    required this.fullName,
    required this.role,
    required this.expiresAt,
  });
  final String userId;
  final String shopId;
  final String fullName;
  final ShopRole role;
  final int expiresAt;
}

abstract interface class AuthRepository {
  Future<OwnerSession?> restore();
  Future<OwnerSession> login(String username, String password);
  Future<void> logout();

  /// Every data operation validates the session and current user/role inside its transaction.
  Future<OwnerSession> authorize(SqlSession tx, Permission permission);
}
