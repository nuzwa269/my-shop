import '../../../core/permissions/permissions.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../domain/auth_repository.dart';
import '../domain/password_hasher.dart';

class LocalStaffRepository {
  LocalStaffRepository(this.db, this.auth, this.hasher, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final PasswordHasher hasher;
  final int Function() now;
  Future<List<Map<String, Object?>>> list() => db.transaction((tx) async {
    final user = await auth.authorize(tx, Permission.staffManagement);
    return tx.select(
      '''SELECT u.id,u.display_name,u.status,u.revision,c.username FROM users u
      JOIN owner_credentials c ON c.user_id=u.id AND c.shop_id=u.shop_id
      WHERE u.shop_id=? AND u.role='cashier' ORDER BY u.display_name,u.id''',
      [user.shopId],
    );
  });
  Future<String> create({
    required String name,
    required String username,
    required String password,
  }) => db.transaction((tx) async {
    final owner = await auth.authorize(tx, Permission.staffManagement);
    final display = Validation.requiredText(name, 'Staff name');
    final login = Validation.username(username);
    Validation.password(password);
    if ((await tx.select('SELECT id FROM owner_credentials WHERE username=?', [
      login,
    ])).isNotEmpty) {
      throw const ValidationException('That username already exists.');
    }
    final hash = await hasher.hash(password);
    final id = await RowWriter.insert(tx, 'users', {
      'shop_id': owner.shopId,
      'display_name': display,
      'role': 'cashier',
    }, now());
    // Historical table name retained to keep existing credentials and schema intact.
    await RowWriter.insert(tx, 'owner_credentials', {
      'shop_id': owner.shopId,
      'user_id': id,
      'username': login,
      'password_hash': hash,
    }, now());
    await RowWriter.audit(
      tx,
      shopId: owner.shopId,
      actorId: owner.userId,
      table: 'users',
      entityId: id,
      action: 'create_cashier',
      reason: 'Owner created restricted staff access',
      now: now(),
      after: {'display_name': display, 'role': 'cashier'},
    );
    return id;
  });
  Future<void> setActive(String id, bool active, int revision) =>
      db.transaction((tx) async {
        final owner = await auth.authorize(tx, Permission.staffManagement);
        final rows = await tx.select(
          "SELECT * FROM users WHERE shop_id=? AND id=? AND role='cashier'",
          [owner.shopId, id],
        );
        if (rows.isEmpty || rows.single['revision'] != revision) {
          throw const ValidationException(
            'Staff account changed or is unavailable. Refresh the list.',
          );
        }
        final status = active ? 'active' : 'archived';
        await tx.execute(
          'UPDATE users SET status=?,revision=revision+1,updated_at=? WHERE id=? AND shop_id=?',
          [status, now(), id, owner.shopId],
        );
        await tx.execute(
          'UPDATE owner_credentials SET status=?,revision=revision+1,updated_at=? WHERE user_id=? AND shop_id=?',
          [status, now(), id, owner.shopId],
        );
        await tx.execute(
          "UPDATE local_sessions SET status='revoked',revision=revision+1,updated_at=? WHERE user_id=? AND shop_id=? AND status='active'",
          [now(), id, owner.shopId],
        );
        await RowWriter.audit(
          tx,
          shopId: owner.shopId,
          actorId: owner.userId,
          table: 'users',
          entityId: id,
          action: active ? 'activate_cashier' : 'deactivate_cashier',
          reason: 'Owner changed staff access',
          now: now(),
        );
      });
}
