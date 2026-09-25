import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/database/migrations/v1_initial.dart';
import 'package:shop_manager/database/sqlite_database.dart';
import 'package:shop_manager/services/id_service.dart';

void main() {
  test(
    'migration 1 to 3 retains existing records and audit protections',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('shop_migration_');
      final file = '${dir.path}/shop.sqlite';
      final original = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, _) async {
            for (final sql in initialSchema) {
              await db.execute(sql);
            }
          },
        ),
      );
      final shop = IdService.newId(),
          user = IdService.newId(),
          product = IdService.newId();
      await original.insert('shops', {
        'id': shop,
        'created_at': 1,
        'updated_at': 1,
        'status': 'active',
        'name': 'Existing Shop',
        'owner_name': 'Owner',
        'business_category': 'spice',
        'currency_code': 'PKR',
        'currency_minor_digits': 2,
      });
      await original.insert('users', {
        'id': user,
        'created_at': 1,
        'updated_at': 1,
        'status': 'active',
        'shop_id': shop,
        'display_name': 'Owner',
        'role': 'owner',
      });
      await original.insert('products', {
        'id': product,
        'created_at': 1,
        'updated_at': 1,
        'status': 'active',
        'shop_id': shop,
        'name': 'Original Variety',
        'base_unit': 'gram',
        'measurement_kind': 'weight',
      });
      await original.close();
      final upgraded = await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      expect(
        (await upgraded.select('PRAGMA user_version')).single.values.single,
        3,
      );
      final row = (await upgraded.select('SELECT * FROM products WHERE id=?', [
        product,
      ])).single;
      expect(row['name'], 'Original Variety');
      expect(row['minimum_stock_scaled'], 0);
      expect(row['purchase_price_id'], isNull);
      expect(await upgraded.select('SELECT * FROM owner_credentials'), isEmpty);
      expect(await upgraded.select('PRAGMA foreign_key_check'), isEmpty);
      await expectLater(
        upgraded.execute("UPDATE products SET base_unit='kg' WHERE id=?", [
          product,
        ]),
        throwsA(isA<DatabaseException>()),
      );
      await upgraded.close();
      await dir.delete(recursive: true);
    },
  );
}
