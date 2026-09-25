import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_connection.dart';
import 'migrations/migration_runner.dart';

class SqliteDatabase implements DatabaseConnection {
  SqliteDatabase._(this._database);
  final Database _database;

  /// The factory and file path are injected for tests and future desktop wiring.
  static Future<SqliteDatabase> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final driver = factory ?? databaseFactory;
    final file =
        databasePath ??
        path.join(await driver.getDatabasesPath(), 'shop_manager.sqlite');
    final database = await driver.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: MigrationRunner.version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => MigrationRunner.upgrade(db, 0, version),
        onUpgrade: MigrationRunner.upgrade,
        // Downgrades fail instead of destructively recreating user data.
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'Database downgrade $oldVersion → $newVersion refused.',
          );
        },
      ),
    );
    return SqliteDatabase._(database);
  }

  @override
  Future<void> execute(String sql, [List<Object?> arguments = const []]) =>
      _database.execute(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) => _database.rawQuery(sql, arguments);

  @override
  Future<T> transaction<T>(Future<T> Function(SqlSession session) action) =>
      _database.transaction((tx) => action(_TransactionSession(tx)));

  @override
  Future<void> close() => _database.close();
}

class _TransactionSession implements SqlSession {
  _TransactionSession(this._transaction);
  final Transaction _transaction;
  @override
  Future<void> execute(String sql, [List<Object?> arguments = const []]) =>
      _transaction.execute(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]) => _transaction.rawQuery(sql, arguments);
}
