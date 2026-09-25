import '../core/numeric/scaled_integer.dart';
import '../core/units/quantity.dart';
import 'record_metadata.dart';

enum StockReason {
  openingStock('opening_stock'),
  purchase('purchase'),
  sale('sale'),
  returned('return'),
  damage('damage'),
  manualAdjustment('manual_adjustment'),
  reversal('reversal'),
  correction('correction');

  const StockReason(this.databaseValue);
  final String databaseValue;
}

/// Immutable movement contract; no mutable current-stock field exists.
class StockTransaction {
  StockTransaction({
    required this.metadata,
    required this.shopId,
    required this.productId,
    required this.quantity,
    required this.direction,
    required this.reason,
    required this.occurredAt,
    required this.createdBy,
    required this.note,
    this.purchaseItemId,
    this.saleItemId,
    this.reversesId,
  }) {
    if ((direction != 1 && direction != -1) ||
        quantity.originalQuantityScaled <= 0 ||
        note.trim().isEmpty) {
      throw ArgumentError(
        'A positive quantity, direction ±1, and reason note are required.',
      );
    }
  }
  final RecordMetadata metadata;
  final String shopId;
  final String productId;
  final QuantitySnapshot quantity;
  final int direction;
  final StockReason reason;
  final int occurredAt;
  final String createdBy;
  final String note;
  final String? purchaseItemId;
  final String? saleItemId;
  final String? reversesId;
  int get quantityDeltaScaled => ScaledInteger.checked(
    BigInt.from(quantity.baseQuantityScaled) * BigInt.from(direction),
  );
}
