import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/database/database_connection.dart';
import 'package:shop_manager/database/sqlite_database.dart';
import 'package:shop_manager/services/id_service.dart';

Future<String> insert(
  SqlSession db,
  String table,
  Map<String, Object?> fields,
) async {
  final row = <String, Object?>{
    'id': IdService.newId(),
    'created_at': 1000,
    'updated_at': 1000,
    'revision': 1,
    'status': 'active',
    ...fields,
  };
  await db.execute(
    'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
    row.values.toList(),
  );
  return row['id']! as String;
}

void main() {
  sqfliteFfiInit();
  late SqliteDatabase db;
  late String shop;
  late String user;
  late String product;
  late String customer;
  late String supplier;

  setUp(() async {
    db = await SqliteDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    shop = await insert(db, 'shops', {
      'name': 'Example',
      'owner_name': 'Owner',
      'business_category': 'flour',
      'currency_code': 'PKR',
      'currency_minor_digits': 2,
    });
    user = await insert(db, 'users', {
      'shop_id': shop,
      'display_name': 'Owner',
      'role': 'owner',
    });
    product = await insert(db, 'products', {
      'shop_id': shop,
      'name': 'Variety',
      'base_unit': 'gram',
      'measurement_kind': 'weight',
    });
    customer = await insert(db, 'customers', {
      'shop_id': shop,
      'name': 'Customer',
    });
    supplier = await insert(db, 'suppliers', {
      'shop_id': shop,
      'name': 'Supplier',
    });
  });
  tearDown(() => db.close());

  Map<String, Object?> document({String status = 'draft'}) => {
    'shop_id': shop,
    'status': status,
    'currency_code': 'PKR',
    'currency_minor_digits': 2,
    'occurred_at': 1000,
    'created_by': user,
    'total_minor': 25000,
    if (status == 'posted') ...{'posted_at': 1000, 'posted_by': user},
  };
  Map<String, Object?> quantity() => {
    'product_id': product,
    'original_unit_code': 'kg',
    'base_unit': 'gram',
    'original_quantity_scaled': 1000000,
    'base_quantity_scaled': 1000000000,
    'conversion_numerator': 1000,
    'conversion_denominator': 1,
  };
  Map<String, Object?> movement() => {
    'shop_id': shop,
    'status': 'posted',
    ...quantity(),
    'occurred_at': 1000,
    'created_by': user,
    'reason': 'opening_stock',
    'quantity_delta_scaled': 1000000000,
    'note': 'Counted opening stock',
  };

  test('migration creates all tables, version, and foreign keys', () async {
    final tables = await db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    expect(
      tables.map((r) => r['name']),
      containsAll([
        'shops',
        'users',
        'products',
        'product_units',
        'customers',
        'suppliers',
        'purchases',
        'purchase_items',
        'sales',
        'sale_items',
        'stock_transactions',
        'customer_ledger_entries',
        'supplier_ledger_entries',
        'expenses',
        'payments',
        'settings',
        'audit_events',
      ]),
    );
    expect((await db.select('PRAGMA user_version')).single.values.single, 3);
    expect((await db.select('PRAGMA foreign_keys')).single.values.single, 1);
    expect(await db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await db.select('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
  });
  test('missing and cross-shop references fail', () async {
    final otherShop = await insert(db, 'shops', {
      'name': 'Other',
      'owner_name': 'Other',
      'business_category': 'spice',
      'currency_code': 'PKR',
      'currency_minor_digits': 2,
    });
    final otherCustomer = await insert(db, 'customers', {
      'shop_id': otherShop,
      'name': 'Other',
    });
    await expectLater(
      insert(db, 'sales', {...document(), 'customer_id': otherCustomer}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      insert(db, 'purchases', {
        ...document(),
        'supplier_id': IdService.newId(),
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute('DELETE FROM shops WHERE id = ?', [shop]),
      throwsA(isA<DatabaseException>()),
    );
  });
  test(
    'unit factors are explicit per variety; weight products use grams',
    () async {
      await insert(db, 'product_units', {
        'shop_id': shop,
        'product_id': product,
        'unit_code': 'bag',
        'base_unit': 'gram',
        'conversion_numerator': 25000,
        'conversion_denominator': 1,
      });
      await expectLater(
        insert(db, 'product_units', {
          'shop_id': shop,
          'product_id': product,
          'unit_code': 'kg',
          'base_unit': 'gram',
          'conversion_numerator': 50,
          'conversion_denominator': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        insert(db, 'products', {
          'shop_id': shop,
          'name': 'Bad',
          'base_unit': 'kg',
          'measurement_kind': 'weight',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test(
    'SQLite refuses fractional money, invalid status and missing posting actor',
    () async {
      await expectLater(
        insert(db, 'sales', {...document(), 'total_minor': 1.5}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        insert(db, 'sales', {...document(), 'status': 'deleted'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        insert(db, 'sales', {...document(), 'status': 'posted'}),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test('completed documents and their lines retain their history', () async {
    final sale = await insert(db, 'sales', {
      ...document(),
      'customer_id': customer,
    });
    final item = await insert(db, 'sale_items', {
      'shop_id': shop,
      'sale_id': sale,
      ...quantity(),
      'unit_price_ticks': 250000000,
      'line_total_minor': 25000,
    });
    await db.execute(
      "UPDATE sales SET status='posted', posted_at=1000, posted_by=? WHERE id=?",
      [user, sale],
    );
    await expectLater(
      db.execute('UPDATE sales SET total_minor=1 WHERE id=?', [sale]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute('DELETE FROM sales WHERE id=?', [sale]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute('UPDATE sale_items SET line_total_minor=1 WHERE id=?', [item]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute('DELETE FROM sale_items WHERE id=?', [item]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      insert(db, 'sale_items', {
        'shop_id': shop,
        'sale_id': sale,
        ...quantity(),
        'unit_price_ticks': 250000000,
        'line_total_minor': 25000,
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute("UPDATE sales SET status='draft' WHERE id=?", [sale]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute("UPDATE sales SET status='cancelled' WHERE id=?", [sale]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.execute(
        "UPDATE sales SET status='cancelled', cancelled_at=2000, cancelled_by=? WHERE id=?",
        [user, sale],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await db.execute(
      "UPDATE sales SET status='cancelled', cancelled_at=2000, cancelled_by=?, cancellation_reason='Entered twice', updated_at=2000, revision=2 WHERE id=?",
      [user, sale],
    );
    expect(
      (await db.select('SELECT total_minor FROM sales WHERE id=?', [
        sale,
      ])).single['total_minor'],
      25000,
    );
    await expectLater(
      db.execute("UPDATE sales SET status='draft' WHERE id=?", [sale]),
      throwsA(isA<DatabaseException>()),
    );
  });
  test(
    'stock sums only posted movements; exact reversals are append-only',
    () async {
      final original = await insert(db, 'stock_transactions', movement());
      await insert(db, 'stock_transactions', {
        ...movement(),
        'status': 'draft',
      });
      expect(
        (await db.select('SELECT quantity_scaled FROM stock_balances'))
            .single['quantity_scaled'],
        1000000000,
      );
      await expectLater(
        db.execute('DELETE FROM stock_transactions WHERE id=?', [original]),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.execute(
          'UPDATE stock_transactions SET quantity_delta_scaled=1 WHERE id=?',
          [original],
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        insert(db, 'stock_transactions', {
          ...movement(),
          'reason': 'reversal',
          'reverses_id': original,
          'quantity_delta_scaled': 1000000000,
        }),
        throwsA(isA<DatabaseException>()),
      );
      final reversal = {
        ...movement(),
        'reason': 'reversal',
        'reverses_id': original,
        'quantity_delta_scaled': -1000000000,
        'note': 'Reverse opening error',
      };
      await insert(db, 'stock_transactions', reversal);
      expect(
        (await db.select('SELECT quantity_scaled FROM stock_balances'))
            .single['quantity_scaled'],
        0,
      );
      await expectLater(
        insert(db, 'stock_transactions', reversal),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  test(
    'both ledgers protect posted entries and validate reversal amount',
    () async {
      for (final side in ['customer', 'supplier']) {
        final table = '${side}_ledger_entries';
        final fields = <String, Object?>{
          'shop_id': shop,
          'status': 'posted',
          '${side}_id': side == 'customer' ? customer : supplier,
          'currency_code': 'PKR',
          'currency_minor_digits': 2,
          'entry_kind': 'opening_balance',
          'amount_delta_minor': 12050,
          'occurred_at': 1000,
          'created_by': user,
          'note': 'Opening balance',
        };
        final original = await insert(db, table, fields);
        await expectLater(
          db.execute('DELETE FROM $table WHERE id=?', [original]),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          insert(db, table, {
            ...fields,
            'entry_kind': 'reversal',
            'reverses_id': original,
            'amount_delta_minor': -12000,
          }),
          throwsA(isA<DatabaseException>()),
        );
        await insert(db, table, {
          ...fields,
          'entry_kind': 'reversal',
          'reverses_id': original,
          'amount_delta_minor': -12050,
        });
        expect(
          (await db.select(
            'SELECT SUM(amount_delta_minor) AS balance FROM $table',
          )).single['balance'],
          0,
        );
      }
    },
  );
  test(
    'audit events are append-only and transactions roll back together',
    () async {
      final event = await insert(db, 'audit_events', {
        'shop_id': shop,
        'status': 'recorded',
        'actor_id': user,
        'entity_table': 'products',
        'entity_id': product,
        'action': 'create',
        'reason': 'Initial entry',
      });
      await expectLater(
        db.execute("UPDATE audit_events SET reason='changed' WHERE id=?", [
          event,
        ]),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.transaction<void>((tx) async {
          await insert(tx, 'customers', {
            'shop_id': shop,
            'name': 'Must roll back',
          });
          throw StateError('Simulated posting failure');
        }),
        throwsStateError,
      );
      expect(
        await db.select("SELECT id FROM customers WHERE name='Must roll back'"),
        isEmpty,
      );
    },
  );
  test(
    'file-backed reopen preserves data; a newer database is never reset',
    () async {
      final folder = await Directory.systemTemp.createTemp('shop_schema_test_');
      final file = '${folder.path}/shop.sqlite';
      final first = await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      final saved = await insert(first, 'shops', {
        'name': 'Persisted',
        'owner_name': 'Owner',
        'business_category': 'rice',
        'currency_code': 'PKR',
        'currency_minor_digits': 2,
      });
      await first.close();
      final second = await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      expect(
        (await second.select('SELECT name FROM shops WHERE id=?', [
          saved,
        ])).single['name'],
        'Persisted',
      );
      await second.execute('PRAGMA user_version=4');
      await second.close();
      await expectLater(
        SqliteDatabase.open(factory: databaseFactoryFfi, databasePath: file),
        throwsStateError,
      );
      final raw = await databaseFactoryFfi.openDatabase(file);
      expect(
        (await raw.rawQuery('SELECT name FROM shops')).single['name'],
        'Persisted',
      );
      await raw.close();
      await folder.delete(recursive: true);
    },
  );
}
