import '../../../core/units/quantity.dart';
import '../../products/domain/product.dart';

enum StockFilter { all, low, out }

bool matchesStock(Product product, StockFilter filter) => switch (filter) {
  StockFilter.all => true,
  StockFilter.low =>
    product.stockScaled > 0 &&
        product.stockScaled <= product.minimumStockScaled,
  StockFilter.out => product.stockScaled <= 0,
};

String stockLabel(Product product) => product.stockScaled <= 0
    ? 'Out of stock'
    : product.stockScaled <= product.minimumStockScaled
    ? 'Low stock'
    : 'In stock';

class StockMovement {
  StockMovement.fromRow(Map<String, Object?> row)
    : id = row['id'] as String,
      reason = row['reason'] as String,
      note = row['note'] as String,
      occurredAt = row['occurred_at'] as int,
      delta = row['quantity_delta_scaled'] as int,
      quantity = QuantitySnapshot.fromRow(row);
  final String id, reason, note;
  final int occurredAt, delta;
  final QuantitySnapshot quantity;
}

class InventoryDetails {
  const InventoryDetails(this.product, this.movements);
  final Product product;
  final List<StockMovement> movements;
}

abstract interface class InventoryRepository {
  Future<List<Product>> list();
  Future<InventoryDetails> details(String productId);
}
