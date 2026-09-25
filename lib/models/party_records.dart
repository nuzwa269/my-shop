import 'record_metadata.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef CustomerRecord = ({
  RecordMetadata metadata,
  String shopId,
  String name,
  String? phone,
  String? address,
  String? note,
});

typedef SupplierRecord = ({
  RecordMetadata metadata,
  String shopId,
  String name,
  String? phone,
  String? address,
  String? note,
});
