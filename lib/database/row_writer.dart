import 'dart:convert';

import '../services/id_service.dart';
import 'database_connection.dart';

/// Internal data-layer helper; table/column names are constants from repositories.
abstract final class RowWriter {
  static Future<String> insert(
    SqlSession tx,
    String table,
    Map<String, Object?> values,
    int now,
  ) async {
    final row = <String, Object?>{
      'id': IdService.newId(),
      'created_at': now,
      'updated_at': now,
      'revision': 1,
      'status': 'active',
      ...values,
    };
    await tx.execute(
      'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
      row.values.toList(),
    );
    return row['id']! as String;
  }

  static Future<void> audit(
    SqlSession tx, {
    required String shopId,
    required String actorId,
    required String table,
    required String entityId,
    required String action,
    required String reason,
    required int now,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  }) async {
    await insert(tx, 'audit_events', {
      'shop_id': shopId,
      'actor_id': actorId,
      'entity_table': table,
      'entity_id': entityId,
      'action': action,
      'reason': reason,
      'status': 'recorded',
      'before_json': before == null ? null : jsonEncode(before),
      'after_json': after == null ? null : jsonEncode(after),
    }, now);
  }
}
