import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../domain/auth_repository.dart';
import '../domain/password_hasher.dart';
import 'session_vault.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.db, this.hasher, this.vault, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final PasswordHasher hasher;
  final SessionVault vault;
  final int Function() now;
  static const sessionDuration = Duration(hours: 12);

  Future<String> _digest(String token) async =>
      base64Encode((await Sha256().hash(utf8.encode(token))).bytes);

  Future<OwnerSession?> _session(SqlSession tx) async {
    final token = await vault.read();
    if (token == null) return null;
    final rows = await tx.select(
      """
      SELECT u.id, u.shop_id, u.display_name, u.role, s.expires_at
      FROM local_sessions s JOIN users u ON u.id=s.user_id AND u.shop_id=s.shop_id
      JOIN shops h ON h.id=s.shop_id
      JOIN owner_credentials c ON c.user_id=u.id AND c.shop_id=u.shop_id
      WHERE s.token_hash=? AND s.status='active' AND s.expires_at>?
      AND u.status='active' AND u.role='owner' AND h.status='active' AND c.status='active'
      """,
      [await _digest(token), now()],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return OwnerSession(
      userId: row['id'] as String,
      shopId: row['shop_id'] as String,
      fullName: row['display_name'] as String,
      role: ShopRole.owner,
      expiresAt: row['expires_at'] as int,
    );
  }

  @override
  Future<OwnerSession?> restore() => db.transaction(_session);

  @override
  Future<OwnerSession> authorize(SqlSession tx, Permission permission) async {
    final session = await _session(tx);
    if (session == null) {
      throw const ValidationException(
        'Your session has ended. Please log in again.',
      );
    }
    if (!RolePermissions.allows(session.role, permission)) {
      throw const ValidationException(
        'You do not have permission for this action.',
      );
    }
    return session;
  }

  @override
  Future<OwnerSession> login(String username, String password) async {
    final key = Validation.username(username);
    if (password.isEmpty || password.length > 128) {
      throw const ValidationException('Invalid username or password/PIN.');
    }
    // Serialize verification and failure accounting to prevent concurrent attempts bypassing throttling.
    final token = await db.transaction<String?>((tx) async {
      final rows = await tx.select(
        """
        SELECT c.*, u.role, u.status AS user_status, h.status AS shop_status
        FROM owner_credentials c JOIN users u ON c.user_id=u.id
        JOIN shops h ON c.shop_id=h.id WHERE c.username=?
        """,
        [key],
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      if ((row['locked_until'] as int) > now()) {
        throw const ValidationException(
          'Too many attempts. Try again after the short lockout.',
        );
      }
      if (row['status'] != 'active' ||
          row['user_status'] != 'active' ||
          row['shop_status'] != 'active' ||
          row['role'] != 'owner') {
        return null;
      }
      final valid = await hasher.verify(
        password,
        row['password_hash'] as String,
      );
      if (!valid) {
        final attempts = (row['failed_attempts'] as int) + 1;
        await tx.execute(
          'UPDATE owner_credentials SET failed_attempts=?,locked_until=?,updated_at=?,revision=revision+1 WHERE id=?',
          [
            attempts,
            attempts >= 5
                ? now() + const Duration(minutes: 1).inMilliseconds
                : 0,
            now(),
            row['id'],
          ],
        );
        return null; // Commit failed-attempt counters before reporting failure.
      }
      await tx.execute(
        'UPDATE owner_credentials SET failed_attempts=0,locked_until=0,updated_at=?,revision=revision+1 WHERE id=?',
        [now(), row['id']],
      );
      await tx.execute(
        "UPDATE local_sessions SET status='revoked',updated_at=?,revision=revision+1 WHERE user_id=? AND status='active'",
        [now(), row['user_id']],
      );
      final random = Random.secure();
      final secret = base64UrlEncode(
        List.generate(32, (_) => random.nextInt(256)),
      );
      await RowWriter.insert(tx, 'local_sessions', {
        'shop_id': row['shop_id'],
        'user_id': row['user_id'],
        'token_hash': await _digest(secret),
        'expires_at': now() + sessionDuration.inMilliseconds,
      }, now());
      return secret;
    });
    if (token == null) {
      throw const ValidationException('Invalid username or password/PIN.');
    }
    try {
      await vault.write(token);
    } catch (_) {
      await db.execute(
        "UPDATE local_sessions SET status='revoked' WHERE token_hash=?",
        [await _digest(token)],
      );
      rethrow;
    }
    final session = await restore();
    if (session == null) {
      throw const ValidationException('Could not start the local session.');
    }
    return session;
  }

  @override
  Future<void> logout() async {
    final token = await vault.read();
    if (token != null) {
      await db.execute(
        "UPDATE local_sessions SET status='revoked',updated_at=?,revision=revision+1 WHERE token_hash=?",
        [now(), await _digest(token)],
      );
    }
    await vault.clear();
  }
}
