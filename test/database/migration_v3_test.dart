import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/database/migrations/migration_runner.dart';
import 'package:shop_manager/database/sqlite_database.dart';
import 'package:shop_manager/services/id_service.dart';

void main() {
  test(
    'existing v2 shop and posted sale survive v3 migration and reopening',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('shop_v3_upgrade_');
      addTearDown(() => dir.delete(recursive: true));
      final file = '${dir.path}/shop.sqlite';
      final original = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => MigrationRunner.upgrade(db, 0, version),
        ),
      );
      final shop = IdService.newId(),
          user = IdService.newId(),
          customer = IdService.newId(),
          sale = IdService.newId();
      final metadata = {'created_at': 1, 'updated_at': 1, 'status': 'active'};
      await original.insert('shops', {
        ...metadata,
        'id': shop,
        'name': 'Preserved shop',
        'owner_name': 'Owner',
        'business_category': 'retail',
        'currency_code': 'PKR',
        'currency_minor_digits': 2,
      });
      await original.insert('users', {
        ...metadata,
        'id': user,
        'shop_id': shop,
        'display_name': 'Owner',
        'role': 'owner',
      });
      await original.insert('customers', {
        ...metadata,
        'id': customer,
        'shop_id': shop,
        'name': 'Existing customer',
      });
      await original.insert('sales', {
        ...metadata,
        'id': sale,
        'shop_id': shop,
        'status': 'posted',
        'currency_code': 'PKR',
        'currency_minor_digits': 2,
        'occurred_at': 1,
        'created_by': user,
        'posted_at': 1,
        'posted_by': user,
        'customer_id': customer,
        'total_minor': 12500,
      });
      final before = (await original.query('sales')).single;
      await original.close();
      var upgraded = await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      try {
        expect(
          (await upgraded.select('PRAGMA user_version')).single.values.single,
          3,
        );
        final after = (await upgraded.select('SELECT * FROM sales')).single;
        for (final field in before.keys) {
          expect(after[field], before[field], reason: field);
        }
        expect(after['receipt_json'], isNull);
        expect(
          (await upgraded.select('SELECT * FROM customers'))
              .single['is_walk_in'],
          0,
        );
        expect(await upgraded.select('PRAGMA foreign_key_check'), isEmpty);
        await expectLater(
          upgraded.execute(
            "UPDATE sales SET receipt_json='changed' WHERE id=?",
            [sale],
          ),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await upgraded.close();
      }
      upgraded = await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      try {
        expect(
          (await upgraded.select('SELECT total_minor FROM sales'))
              .single['total_minor'],
          12500,
        );
        expect(
          (await upgraded.select('PRAGMA integrity_check'))
              .single
              .values
              .single,
          'ok',
        );
      } finally {
        await upgraded.close();
      }
    },
  );
}
