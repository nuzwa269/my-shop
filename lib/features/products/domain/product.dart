import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';

class ProductInput {
  const ProductInput({
    required this.name,
    required this.baseUnit,
    required this.measurementKind,
    required this.primaryUnit,
    required this.defaultSaleUnit,
    required this.units,
    required this.purchasePrice,
    required this.purchasePriceUnit,
    required this.salePrice,
    required this.salePriceUnit,
    this.minimumStock = '0',
    this.sku = '',
    this.description = '',
  });
  final String name,
      sku,
      description,
      baseUnit,
      measurementKind,
      primaryUnit,
      defaultSaleUnit,
      purchasePrice,
      purchasePriceUnit,
      salePrice,
      salePriceUnit,
      minimumStock;
  final List<UnitConversion> units;
}

class PriceSnapshot {
  const PriceSnapshot({
    required this.id,
    required this.kind,
    required this.amountTicks,
    required this.currency,
    required this.conversion,
    required this.createdAt,
  });
  final String id, kind;
  final int amountTicks, createdAt;
  final Currency currency;
  final UnitConversion conversion;
  factory PriceSnapshot.fromRow(Map<String, Object?> row) => PriceSnapshot(
    id: row['id'] as String,
    kind: row['price_kind'] as String,
    amountTicks: row['amount_ticks'] as int,
    currency: Currency(
      row['currency_code'] as String,
      minorDigits: row['currency_minor_digits'] as int,
    ),
    conversion: UnitConversionService.fromRow(row),
    createdAt: row['created_at'] as int,
  );
}

class OpeningStock {
  OpeningStock.fromRow(Map<String, Object?> row)
    : id = row['id'] as String,
      quantity = QuantitySnapshot.fromRow(row),
      valueMinor = row['opening_value_minor'] as int?,
      occurredAt = row['occurred_at'] as int;
  final String id;
  final QuantitySnapshot quantity;
  final int? valueMinor;
  final int occurredAt;
}

class Product {
  Product.fromRow(Map<String, Object?> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      shopId = row['shop_id'] as String,
      sku = row['sku'] as String?,
      description = row['description'] as String?,
      baseUnit = row['base_unit'] as String,
      measurementKind = row['measurement_kind'] as String,
      primaryUnit =
          row['primary_unit_code'] as String? ?? row['base_unit'] as String,
      defaultSaleUnit =
          row['default_sale_unit_code'] as String? ??
          row['base_unit'] as String,
      minimumStockScaled = row['minimum_stock_scaled'] as int,
      active = row['status'] == 'active',
      revision = row['revision'] as int,
      stockScaled = row['stock_scaled'] as int? ?? 0;
  final String id,
      shopId,
      name,
      baseUnit,
      measurementKind,
      primaryUnit,
      defaultSaleUnit;
  final String? sku, description;
  final int minimumStockScaled, revision, stockScaled;
  final bool active;
}

class ProductDetails {
  const ProductDetails({
    required this.product,
    required this.units,
    required this.prices,
    this.purchasePrice,
    this.salePrice,
    this.opening,
  });
  final Product product;
  final List<UnitConversion> units;
  final List<PriceSnapshot> prices;
  final PriceSnapshot? purchasePrice, salePrice;
  final OpeningStock? opening;
}

class OpeningInput {
  const OpeningInput({
    required this.quantity,
    required this.unit,
    required this.occurredAt,
    this.totalValue = '',
    this.reason = 'Initial stock count',
  });
  final String quantity, unit, totalValue, reason;
  final int occurredAt;
}

abstract interface class ProductRepository {
  Future<List<Product>> list({String search = '', bool? active});
  Future<ProductDetails> details(String id);
  Future<String> save(
    ProductInput input, {
    String? id,
    int? expectedRevision,
    OpeningInput? opening,
  });
  Future<void> setActive(String id, bool active, int expectedRevision);
  Future<void> setOpening(
    String id,
    OpeningInput input, {
    required int expectedRevision,
    String? expectedOpeningId,
  });
}
