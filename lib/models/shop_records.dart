import 'record_metadata.dart';
import '../core/permissions/permissions.dart';
import '../core/money/money.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef ShopRecord = ({
  RecordMetadata metadata,
  String name,
  String ownerName,
  String businessCategory,
  Currency currency,
});

typedef UserRecord = ({
  RecordMetadata metadata,
  String shopId,
  String displayName,
  ShopRole role,
});

typedef SettingRecord = ({
  RecordMetadata metadata,
  String shopId,
  String key,
  String valueJson,
});
