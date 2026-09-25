import 'record_metadata.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef ProductRecord = ({
  RecordMetadata metadata,
  String shopId,
  String name,
  String baseUnit,
  String measurementKind,
});

typedef ProductUnitRecord = ({
  RecordMetadata metadata,
  String shopId,
  String productId,
  String unitCode,
  String baseUnit,
  int conversionNumerator,
  int conversionDenominator,
});
