/// Shared persistence identity. IDs are UUID v4; time values are UTC Unix ms.
/// Revisions support later optimistic concurrency; they are not a sync protocol.
class RecordMetadata {
  const RecordMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.revision = 1,
  });
  final String id;
  final int createdAt;
  final int updatedAt;
  final RecordStatus status;
  final int revision;
}

enum RecordStatus {
  active('active'),
  archived('archived'),
  draft('draft'),
  posted('posted'),
  cancelled('cancelled'),
  voided('void'),
  recorded('recorded');

  const RecordStatus(this.databaseValue);
  final String databaseValue;
}
