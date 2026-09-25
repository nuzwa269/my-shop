import 'record_metadata.dart';
import '../core/money/money.dart';
import '../core/units/quantity.dart';

// Immutable domain contracts. Feature data layers will add row mapping when used.
// No repository, CRUD, posting workflow, or financial calculation is implied here.

typedef PurchaseRecord = ({
  RecordMetadata metadata,
  String shopId,
  int occurredAt,
  String createdBy,
  int? postedAt,
  String? postedBy,
  int? cancelledAt,
  String? cancelledBy,
  String? cancellationReason,
  String? reversesId,
  String? correctsId,
  String? note,
  String supplierId,
  String? documentNumber,
  String documentKind,
  int totalMinor,
  Currency currency,
});

typedef PurchaseItemRecord = ({
  RecordMetadata metadata,
  String shopId,
  String purchaseId,
  String productId,
  int unitPriceTicks,
  int lineTotalMinor,
  QuantitySnapshot quantity,
});

typedef SaleRecord = ({
  RecordMetadata metadata,
  String shopId,
  int occurredAt,
  String createdBy,
  int? postedAt,
  String? postedBy,
  int? cancelledAt,
  String? cancelledBy,
  String? cancellationReason,
  String? reversesId,
  String? correctsId,
  String? note,
  String? customerId,
  String? documentNumber,
  String documentKind,
  int totalMinor,
  Currency currency,
});

typedef SaleItemRecord = ({
  RecordMetadata metadata,
  String shopId,
  String saleId,
  String productId,
  int unitPriceTicks,
  int lineTotalMinor,
  QuantitySnapshot quantity,
});

typedef ExpenseRecord = ({
  RecordMetadata metadata,
  String shopId,
  int occurredAt,
  String createdBy,
  int? postedAt,
  String? postedBy,
  int? cancelledAt,
  String? cancelledBy,
  String? cancellationReason,
  String? reversesId,
  String? correctsId,
  String? note,
  String category,
  String description,
  int totalMinor,
  Currency currency,
});

typedef PaymentRecord = ({
  RecordMetadata metadata,
  String shopId,
  int occurredAt,
  String createdBy,
  int? postedAt,
  String? postedBy,
  int? cancelledAt,
  String? cancelledBy,
  String? cancellationReason,
  String? reversesId,
  String? correctsId,
  String? note,
  String direction,
  String method,
  int amountMinor,
  String? customerId,
  String? supplierId,
  String? saleId,
  String? purchaseId,
  String? expenseId,
  Currency currency,
});
