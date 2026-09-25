import 'package:sqflite/sqflite.dart';

import 'v1_initial.dart';
import 'v2_shop_products.dart';
import 'v3_mvp.dart';

abstract final class MigrationRunner {
  static const version = 3;
  static final _migrations = <int, List<String>>{
    1: initialSchema,
    2: phase2Schema,
    3: mvpSchema,
  };

  /// sqflite wraps onCreate/onUpgrade callbacks in a transaction.
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final statements = _migrations[version];
      if (statements == null) throw StateError('Missing migration $version');
      for (final statement in statements) {
        await db.execute(statement);
      }
    }
  }
}
