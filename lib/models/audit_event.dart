import 'record_metadata.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef AuditEvent = ({
  RecordMetadata metadata,
  String shopId,
  String actorId,
  String entityTable,
  String entityId,
  String action,
  String reason,
  String? beforeJson,
  String? afterJson,
});
