import 'record_metadata.dart';
import '../core/money/money.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef CustomerLedgerEntryRecord = ({
  RecordMetadata metadata,
  String shopId,
  String customerId,
  String? saleId,
  String? paymentId,
  String? reversesId,
  int occurredAt,
  String createdBy,
  String entryKind,
  int amountDeltaMinor,
  String note,
  Currency currency,
});

typedef SupplierLedgerEntryRecord = ({
  RecordMetadata metadata,
  String shopId,
  String supplierId,
  String? purchaseId,
  String? paymentId,
  String? reversesId,
  int occurredAt,
  String createdBy,
  String entryKind,
  int amountDeltaMinor,
  String note,
  Currency currency,
});
