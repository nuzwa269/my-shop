import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/product.dart';

class LocalProductRepository implements ProductRepository {
  LocalProductRepository(this.db, this.auth, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final int Function() now;

  static const _selectProduct = """
    SELECT p.*, COALESCE(b.quantity_scaled,0) AS stock_scaled FROM products p
    LEFT JOIN stock_balances b ON b.shop_id=p.shop_id AND b.product_id=p.id
    """;

  Future<Map<String, Object?>> _row(
    SqlSession tx,
    String shop,
    String id,
  ) async {
    final rows = await tx.select(
      '$_selectProduct WHERE p.shop_id=? AND p.id=?',
      [shop, id],
    );
    if (rows.isEmpty) throw const ValidationException('Product not found.');
    return rows.single;
  }

  void _revision(Map<String, Object?> row, int? expected) {
    if (expected == null || row['revision'] != expected) {
      throw const ValidationException(
        'This product changed. Reopen it before saving.',
      );
    }
  }

  Future<Currency> _currency(SqlSession tx, String shop) async {
    final row = (await tx.select(
      'SELECT currency_code,currency_minor_digits FROM shops WHERE id=?',
      [shop],
    )).single;
    return Currency(
      row['currency_code'] as String,
      minorDigits: row['currency_minor_digits'] as int,
    );
  }

  @override
  Future<List<Product>> list({
    String search = '',
    bool? active,
  }) => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.products);
    final rows = await tx.select(
      '$_selectProduct WHERE p.shop_id=? ORDER BY p.name COLLATE NOCASE,p.id',
      [session.shopId],
    );
    final key = Validation.key(search);
    return rows
        .map(Product.fromRow)
        .where(
          (p) =>
              (active == null || p.active == active) &&
              (Validation.key(p.name).contains(key) ||
                  (p.sku?.toLowerCase().contains(key) ?? false)),
        )
        .toList();
  });

  @override
  Future<ProductDetails> details(String id) => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.products);
    final row = await _row(tx, session.shopId, id);
    final units = await tx.select(
      "SELECT * FROM product_units WHERE shop_id=? AND product_id=? AND status='active' ORDER BY unit_code",
      [session.shopId, id],
    );
    final priceRows = await tx.select(
      'SELECT * FROM product_prices WHERE shop_id=? AND product_id=? ORDER BY created_at DESC,id',
      [session.shopId, id],
    );
    final prices = priceRows.map(PriceSnapshot.fromRow).toList();
    PriceSnapshot? price(String? priceId) {
      for (final item in prices) {
        if (item.id == priceId) return item;
      }
      return null;
    }

    OpeningStock? opening;
    if (row['opening_transaction_id'] != null) {
      opening = OpeningStock.fromRow(
        (await tx.select(
          'SELECT * FROM stock_transactions WHERE id=? AND shop_id=?',
          [row['opening_transaction_id'], session.shopId],
        )).single,
      );
    }
    return ProductDetails(
      product: Product.fromRow(row),
      units: units.map((u) => UnitConversionService.fromRow(u)).toList(),
      prices: prices,
      purchasePrice: price(row['purchase_price_id'] as String?),
      salePrice: price(row['sale_price_id'] as String?),
      opening: opening,
    );
  });

  int _price(String text, Currency currency) {
    try {
      final ticks = Money.parseUnitPrice(text, currency);
      if (ticks < 0) {
        throw const ValidationException('Prices cannot be negative.');
      }
      return ticks;
    } on FormatException {
      throw const ValidationException(
        'Enter a valid price (PKR supports at most 6 decimal places).',
      );
    } on RangeError {
      throw const ValidationException('Price is too large.');
    }
  }

  @override
  Future<String> save(
    ProductInput input, {
    String? id,
    int? expectedRevision,
    OpeningInput? opening,
  }) => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.products);
    final shop = session.shopId;
    final name = Validation.requiredText(input.name, 'Product name');
    final key = Validation.key(name);
    final sku = Validation.optional(input.sku, max: 60)?.toUpperCase();
    final description = Validation.optional(input.description);
    final all = await tx.select(
      'SELECT id,name,sku FROM products WHERE shop_id=?',
      [shop],
    );
    if (all.any(
      (p) => p['id'] != id && Validation.key(p['name'] as String) == key,
    )) {
      throw const ValidationException(
        'A product with this name already exists, including inactive products.',
      );
    }
    if (sku != null && all.any((p) => p['id'] != id && p['sku'] == sku)) {
      throw const ValidationException('This SKU/code is already used.');
    }
    if (!['weight', 'custom'].contains(input.measurementKind)) {
      throw const ValidationException('Choose weight or a custom measurement.');
    }
    final base = UnitConversionService.code(input.baseUnit);
    if (input.measurementKind == 'weight' && base != 'gram') {
      throw const ValidationException(
        'Weight products must use grams as their base unit.',
      );
    }
    final units = <String, UnitConversion>{};
    for (final unit in input.units) {
      if (unit.baseUnit != base ||
          UnitConversionService.code(unit.unitCode) != unit.unitCode ||
          unit.numerator > 1000000000 ||
          unit.denominator > 1000000000) {
        throw const ValidationException('Invalid product unit conversion.');
      }
      if (units.containsKey(unit.unitCode)) {
        throw const ValidationException('Each unit can be defined only once.');
      }
      units[unit.unitCode] = unit;
    }
    final baseConversion = units[base];
    if (baseConversion == null ||
        baseConversion.numerator != baseConversion.denominator) {
      throw const ValidationException(
        'Define the base unit with a 1:1 factor.',
      );
    }
    for (final code in [
      input.primaryUnit,
      input.defaultSaleUnit,
      input.purchasePriceUnit,
      input.salePriceUnit,
    ]) {
      if (!units.containsKey(code)) {
        throw const ValidationException(
          'Define every stock, sale and pricing unit before saving.',
        );
      }
    }
    final currency = await _currency(tx, shop);
    final purchase = _price(input.purchasePrice, currency);
    final sale = _price(input.salePrice, currency);
    int minimum;
    try {
      minimum = Quantity.parse(input.minimumStock);
    } on FormatException {
      throw const ValidationException('Invalid minimum stock quantity.');
    } on RangeError {
      throw const ValidationException('Minimum stock quantity is too large.');
    }
    if (minimum < 0) {
      throw const ValidationException('Minimum stock cannot be negative.');
    }
    Map<String, Object?>? before;
    final timestamp = now();
    String productId;
    if (id == null) {
      productId = await RowWriter.insert(tx, 'products', {
        'shop_id': shop,
        'name': name,
        'name_key': key,
        'sku': sku,
        'description': description,
        'base_unit': base,
        'measurement_kind': input.measurementKind,
        'minimum_stock_scaled': minimum,
      }, timestamp);
    } else {
      productId = id;
      before = await _row(tx, shop, id);
      _revision(before, expectedRevision);
      if (before['base_unit'] != base ||
          before['measurement_kind'] != input.measurementKind) {
        throw const ValidationException(
          'A product base unit cannot change. Create a separate product instead.',
        );
      }
      if (opening != null) {
        throw const ValidationException(
          'Use the opening-stock correction screen to change opening stock.',
        );
      }
    }
    final oldUnits = await tx.select(
      'SELECT * FROM product_units WHERE shop_id=? AND product_id=?',
      [shop, productId],
    );
    for (final unit in units.values) {
      final existing = oldUnits
          .where((r) => r['unit_code'] == unit.unitCode)
          .firstOrNull;
      if (existing == null) {
        await RowWriter.insert(tx, 'product_units', {
          'shop_id': shop,
          'product_id': productId,
          ...UnitConversionService.toRow(unit),
        }, timestamp);
      } else {
        await tx.execute(
          """UPDATE product_units SET conversion_numerator=?,conversion_denominator=?,
            status='active',updated_at=?,revision=revision+1 WHERE id=?""",
          [unit.numerator, unit.denominator, timestamp, existing['id']],
        );
      }
    }
    for (final old in oldUnits) {
      if (!units.containsKey(old['unit_code'])) {
        await tx.execute(
          "UPDATE product_units SET status='archived',updated_at=?,revision=revision+1 WHERE id=?",
          [timestamp, old['id']],
        );
      }
    }
    final purchaseId = await _savePrice(
      tx,
      session,
      productId,
      'purchase',
      purchase,
      currency,
      units[input.purchasePriceUnit]!,
      before?['purchase_price_id'] as String?,
      timestamp,
    );
    final saleId = await _savePrice(
      tx,
      session,
      productId,
      'sale',
      sale,
      currency,
      units[input.salePriceUnit]!,
      before?['sale_price_id'] as String?,
      timestamp,
    );
    await tx.execute(
      """UPDATE products SET name=?,name_key=?,sku=?,description=?,
        primary_unit_code=?,default_sale_unit_code=?,minimum_stock_scaled=?,
        purchase_price_id=?,sale_price_id=?,updated_at=?,revision=revision+? WHERE id=? AND shop_id=?""",
      [
        name,
        key,
        sku,
        description,
        input.primaryUnit,
        input.defaultSaleUnit,
        minimum,
        purchaseId,
        saleId,
        timestamp,
        id == null ? 0 : 1,
        productId,
        shop,
      ],
    );
    await RowWriter.audit(
      tx,
      shopId: shop,
      actorId: session.userId,
      table: 'products',
      entityId: productId,
      action: id == null ? 'create' : 'update',
      reason: id == null ? 'Product setup' : 'Product configuration changed',
      now: timestamp,
      before: before == null ? null : {'product': before, 'units': oldUnits},
      after: {
        'product': await _row(tx, shop, productId),
        'units': units.values.map(UnitConversionService.toRow).toList(),
      },
    );
    if (opening != null) {
      await _opening(
        tx,
        session,
        productId,
        opening,
        expectedRevision: 1,
        expectedOpeningId: null,
      );
    }
    return productId;
  });

  Future<String> _savePrice(
    SqlSession tx,
    OwnerSession session,
    String productId,
    String kind,
    int amount,
    Currency currency,
    UnitConversion unit,
    String? currentId,
    int timestamp,
  ) async {
    final payload = <String, Object?>{
      'shop_id': session.shopId,
      'product_id': productId,
      'price_kind': kind,
      'amount_ticks': amount,
      'currency_code': currency.code,
      'currency_minor_digits': currency.minorDigits,
      ...UnitConversionService.toRow(unit),
    };
    if (currentId != null) {
      final old = (await tx.select('SELECT * FROM product_prices WHERE id=?', [
        currentId,
      ])).single;
      if (payload.entries.every((entry) => old[entry.key] == entry.value)) {
        return currentId;
      }
    }
    return RowWriter.insert(tx, 'product_prices', {
      ...payload,
      'created_by': session.userId,
      'status': 'recorded',
    }, timestamp);
  }

  @override
  Future<void> setActive(String id, bool active, int expectedRevision) =>
      db.transaction((tx) async {
        final session = await auth.authorize(tx, Permission.products);
        final before = await _row(tx, session.shopId, id);
        _revision(before, expectedRevision);
        final timestamp = now();
        await tx.execute(
          'UPDATE products SET status=?,updated_at=?,revision=revision+1 WHERE id=? AND shop_id=?',
          [active ? 'active' : 'archived', timestamp, id, session.shopId],
        );
        await RowWriter.audit(
          tx,
          shopId: session.shopId,
          actorId: session.userId,
          table: 'products',
          entityId: id,
          action: active ? 'reactivate' : 'deactivate',
          reason: active ? 'Product reactivated' : 'Product deactivated',
          now: timestamp,
          before: before,
          after: await _row(tx, session.shopId, id),
        );
      });

  @override
  Future<void> setOpening(
    String id,
    OpeningInput input, {
    required int expectedRevision,
    String? expectedOpeningId,
  }) => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.stockAdjustments);
    await _opening(
      tx,
      session,
      id,
      input,
      expectedRevision: expectedRevision,
      expectedOpeningId: expectedOpeningId,
    );
  });

  Future<void> _opening(
    SqlSession tx,
    OwnerSession session,
    String id,
    OpeningInput input, {
    required int expectedRevision,
    required String? expectedOpeningId,
  }) async {
    if (!RolePermissions.allows(session.role, Permission.stockAdjustments)) {
      throw const ValidationException(
        'Opening stock requires stock-adjustment permission.',
      );
    }
    final product = await _row(tx, session.shopId, id);
    _revision(product, expectedRevision);
    if (product['status'] != 'active') {
      throw const ValidationException(
        'Reactivate this product before entering opening stock.',
      );
    }
    if (product['opening_transaction_id'] != expectedOpeningId) {
      throw const ValidationException(
        'Opening stock changed. Reopen this screen.',
      );
    }
    if ((await tx.select(
      """SELECT id FROM stock_transactions WHERE shop_id=? AND product_id=?
      AND status='posted' AND reason NOT IN ('opening_stock','reversal') LIMIT 1""",
      [session.shopId, id],
    )).isNotEmpty) {
      throw const ValidationException(
        'Opening stock is locked after other movements. Use a later stock-adjustment workflow.',
      );
    }
    final unitRows = await tx.select(
      "SELECT * FROM product_units WHERE shop_id=? AND product_id=? AND unit_code=? AND status='active'",
      [session.shopId, id, input.unit],
    );
    if (unitRows.isEmpty) {
      throw const ValidationException(
        'Define this product unit before entering opening stock.',
      );
    }
    final snapshot = UnitConversionService.snapshot(
      input.quantity,
      UnitConversionService.fromRow(unitRows.single),
    );
    final reason = Validation.requiredText(input.reason, 'Reason', max: 500);
    final timestamp = now();
    if (input.occurredAt <= 0 || input.occurredAt > timestamp) {
      throw const ValidationException(
        'Opening time must be a valid past or current time.',
      );
    }
    final currency = await _currency(tx, session.shopId);
    int? value;
    if (input.totalValue.trim().isNotEmpty) {
      try {
        value = Money.parse(input.totalValue, currency);
      } on FormatException {
        throw const ValidationException(
          'Opening value must use currency minor-unit precision (2 places for PKR).',
        );
      } on RangeError {
        throw const ValidationException('Opening value is too large.');
      }
      if (value < 0) {
        throw const ValidationException('Opening value cannot be negative.');
      }
    }
    Map<String, Object?>? previous;
    if (expectedOpeningId != null) {
      previous = (await tx.select(
        'SELECT * FROM stock_transactions WHERE id=? AND shop_id=?',
        [expectedOpeningId, session.shopId],
      )).single;
      await RowWriter.insert(tx, 'stock_transactions', {
        'shop_id': session.shopId,
        'product_id': id,
        ...QuantitySnapshot.fromRow(previous).toRow(),
        'status': 'posted',
        'occurred_at': timestamp,
        'created_by': session.userId,
        'reason': 'reversal',
        'quantity_delta_scaled': -(previous['quantity_delta_scaled'] as int),
        'reverses_id': expectedOpeningId,
        'note': reason,
        'opening_value_minor': previous['opening_value_minor'] == null
            ? null
            : -(previous['opening_value_minor'] as int),
        'value_currency_code': previous['value_currency_code'],
        'value_currency_minor_digits': previous['value_currency_minor_digits'],
      }, timestamp);
    }
    final newId = await RowWriter.insert(tx, 'stock_transactions', {
      'shop_id': session.shopId,
      'product_id': id,
      ...snapshot.toRow(),
      'status': 'posted',
      'occurred_at': input.occurredAt,
      'created_by': session.userId,
      'reason': 'opening_stock',
      'quantity_delta_scaled': snapshot.baseQuantityScaled,
      'note': reason,
      'opening_value_minor': value,
      'value_currency_code': value == null ? null : currency.code,
      'value_currency_minor_digits': value == null
          ? null
          : currency.minorDigits,
    }, timestamp);
    await tx.execute(
      'UPDATE products SET opening_transaction_id=?,updated_at=?,revision=revision+1 WHERE id=? AND shop_id=?',
      [newId, timestamp, id, session.shopId],
    );
    // Force SQLite aggregate validation before commit; an overflow rolls back the entire correction.
    await _row(tx, session.shopId, id);
    await RowWriter.audit(
      tx,
      shopId: session.shopId,
      actorId: session.userId,
      table: 'stock_transactions',
      entityId: newId,
      action: previous == null ? 'opening_stock' : 'correct_opening_stock',
      reason: reason,
      now: timestamp,
      before: previous,
      after: (await tx.select('SELECT * FROM stock_transactions WHERE id=?', [
        newId,
      ])).single,
    );
  }
}
