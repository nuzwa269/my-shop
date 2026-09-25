import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/core/units/quantity.dart';
import 'package:shop_manager/core/units/unit_conversion_service.dart';
import 'package:shop_manager/core/validation/validation.dart';

import '../support/test_store.dart';

void main() {
  late TestStore store;
  setUp(() async {
    store = await TestStore.open();
  });
  tearDown(() => store.close());
  test('product create, read, edit, search, deactivate and reactivate preserve identity', () async {
    final id = await store.products.save(TestStore.product(sku: 'R-01'));
    var details = await store.products.details(id);
    expect(details.product.name, 'Super Basmati');
    expect(details.purchasePrice!.conversion.unitCode, 'bag');
    expect(details.salePrice!.conversion.unitCode, 'kg');
    expect(details.purchasePrice!.amountTicks, 12000000000);
    expect(details.product.minimumStockScaled, Quantity.parse('1000'));
    expect(await store.products.list(search: 'r-01'), hasLength(1));
    await store.products.save(
      TestStore.product(name: '1121 Sella', sku: 'R-01'),
      id: id,
      expectedRevision: details.product.revision,
    );
    details = await store.products.details(id);
    expect(details.product.id, id);
    expect(details.product.name, '1121 Sella');
    await store.products.setActive(id, false, details.product.revision);
    expect(await store.products.list(active: true), isEmpty);
    expect(await store.products.list(active: false), hasLength(1));
    details = await store.products.details(id);
    await store.products.setActive(id, true, details.product.revision);
    expect(await store.products.list(active: true), hasLength(1));
    await expectLater(
      store.db.execute('DELETE FROM products WHERE id=?', [id]),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      await store.db.select(
        "SELECT * FROM audit_events WHERE entity_table='products'",
      ),
      hasLength(4),
    );
  });
  test('validation rejects duplicates, invalid prices, missing factors and negative minima', () async {
    final id = await store.products.save(TestStore.product());
    await store.products.setActive(id, false, 1);
    for (final input in [
      TestStore.product(name: ' super   basmati '),
      TestStore.product(name: 'Bad price', sale: '-1'),
      TestStore.product(name: 'Exponent', purchase: '1e3'),
      TestStore.product(name: 'Undefined', purchaseUnit: 'sack'),
      TestStore.product(name: 'Minimum', minimum: '-1'),
      TestStore.product(name: ''),
    ]) {
      await expectLater(
        store.products.save(input),
        throwsA(isA<ValidationException>()),
      );
    }
    expect(await store.products.list(), hasLength(1));
  });
  test(
    'stale edits are rejected and no-op price save does not duplicate history',
    () async {
      final id = await store.products.save(TestStore.product());
      await store.products.save(
        TestStore.product(),
        id: id,
        expectedRevision: 1,
      );
      expect((await store.products.details(id)).prices, hasLength(2));
      await expectLater(
        store.products.save(
          TestStore.product(name: 'Stale'),
          id: id,
          expectedRevision: 1,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await store.products.details(id)).product.name, 'Super Basmati');
    },
  );
  test('unit changes append prices without rewriting historical factors or opening stock', () async {
    final id = await store.products.save(
      TestStore.product(),
      opening: store.opening(),
    );
    final original = await store.products.details(id);
    await store.products.save(
      TestStore.product(bagGrams: 25000),
      id: id,
      expectedRevision: original.product.revision,
    );
    final updated = await store.products.details(id);
    expect(updated.purchasePrice!.conversion.numerator, 25000);
    expect(updated.prices, hasLength(3));
    final old = updated.prices.singleWhere(
      (p) => p.id == original.purchasePrice!.id,
    );
    expect(old.conversion.numerator, 50000);
    expect(
      updated.opening!.quantity.baseQuantityScaled,
      Quantity.parse('100000'),
    );
    await expectLater(
      store.db.execute('UPDATE product_prices SET amount_ticks=1 WHERE id=?', [
        old.id,
      ]),
      throwsA(isA<DatabaseException>()),
    );
    final quantity = UnitConversionService.snapshot(
      '2',
      UnitConversion.kilograms(),
    );
    expect(
      UnitConversionService.priceTotal(
        priceTicks: old.amountTicks,
        pricingConversion: old.conversion,
        quantity: quantity,
      ),
      48000,
    );
    expect(
      UnitConversionService.priceTotal(
        priceTicks: updated.purchasePrice!.amountTicks,
        pricingConversion: updated.purchasePrice!.conversion,
        quantity: quantity,
      ),
      96000,
    );
  });
  test('opening stock records original, normalized quantity, optional value and audit', () async {
    final id = await store.products.save(
      TestStore.product(),
      opening: store.opening(),
    );
    final details = await store.products.details(id);
    expect(details.product.stockScaled, Quantity.parse('100000'));
    expect(
      details.opening!.quantity.originalQuantityScaled,
      Quantity.parse('2'),
    );
    expect(details.opening!.quantity.conversion.unitCode, 'bag');
    expect(details.opening!.valueMinor, 2400000);
    expect(
      await store.db.select(
        "SELECT * FROM audit_events WHERE action='opening_stock'",
      ),
      hasLength(1),
    );
    expect(
      await store.db.select('SELECT * FROM customer_ledger_entries'),
      isEmpty,
    );
    expect(
      await store.db.select('SELECT * FROM supplier_ledger_entries'),
      isEmpty,
    );
  });
  test('opening correction appends exact reversal, replacement and audit atomically', () async {
    final id = await store.products.save(
      TestStore.product(),
      opening: store.opening(),
    );
    final original = await store.products.details(id);
    await store.products.setOpening(
      id,
      store.opening(quantity: '1', value: '12000', reason: 'Count corrected'),
      expectedRevision: original.product.revision,
      expectedOpeningId: original.opening!.id,
    );
    final changed = await store.products.details(id);
    expect(changed.product.stockScaled, Quantity.parse('50000'));
    expect(changed.opening!.id, isNot(original.opening!.id));
    final rows = await store.db.select(
      'SELECT * FROM stock_transactions WHERE product_id=?',
      [id],
    );
    expect(rows, hasLength(3));
    final reversal = rows.singleWhere((r) => r['reason'] == 'reversal');
    expect(reversal['quantity_delta_scaled'], -Quantity.parse('100000'));
    expect(reversal['opening_value_minor'], -2400000);
    expect(reversal['reverses_id'], original.opening!.id);
    final retained = rows.singleWhere((r) => r['id'] == original.opening!.id);
    expect(retained['status'], 'posted');
    expect(retained['opening_value_minor'], 2400000);
    expect(
      await store.db.select(
        "SELECT * FROM audit_events WHERE action='correct_opening_stock'",
      ),
      hasLength(1),
    );
    await expectLater(
      store.products.setOpening(
        id,
        store.opening(),
        expectedRevision: original.product.revision,
        expectedOpeningId: original.opening!.id,
      ),
      throwsA(isA<ValidationException>()),
    );
  });
  test('invalid opening rolls back product, units, prices and audit', () async {
    final before = (await store.db.select('SELECT * FROM audit_events')).length;
    await expectLater(
      store.products.save(
        TestStore.product(),
        opening: store.opening(quantity: '-1'),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await store.products.list(), isEmpty);
    expect(await store.db.select('SELECT * FROM product_units'), isEmpty);
    expect(await store.db.select('SELECT * FROM product_prices'), isEmpty);
    expect(
      await store.db.select('SELECT * FROM audit_events'),
      hasLength(before),
    );
  });
  test(
    'invalid correction leaves original stock and value untouched',
    () async {
      final id = await store.products.save(
        TestStore.product(),
        opening: store.opening(value: ''),
      );
      final current = await store.products.details(id);
      for (final invalid in [
        store.opening(quantity: '0'),
        store.opening(unit: 'sack'),
        store.opening(value: '1.001'),
        store.opening(reason: ''),
      ]) {
        await expectLater(
          store.products.setOpening(
            id,
            invalid,
            expectedRevision: current.product.revision,
            expectedOpeningId: current.opening!.id,
          ),
          throwsA(isA<ValidationException>()),
        );
      }
      expect(
        (await store.products.details(id)).product.stockScaled,
        Quantity.parse('100000'),
      );
      expect(
        await store.db.select('SELECT * FROM stock_transactions'),
        hasLength(1),
      );
      expect(current.opening!.valueMinor, isNull);
    },
  );
  test(
    'conversion input and price totals remain exact across unlike units',
    () {
      final bag = UnitConversionService.define(
        unit: 'bag',
        baseUnit: 'gram',
        factor: '50',
        factorInKg: true,
      );
      expect(bag.numerator, 50000);
      expect(
        () => UnitConversionService.define(
          unit: 'maund',
          baseUnit: 'gram',
          factor: '0',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => UnitConversionService.define(
          unit: 'kg',
          baseUnit: 'gram',
          factor: '5',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => UnitConversionService.snapshot('1.0000001', bag),
        throwsA(isA<ValidationException>()),
      );
      expect(
        UnitConversionService.priceTotal(
          priceTicks: 260000000,
          pricingConversion: UnitConversion.kilograms(),
          quantity: UnitConversionService.snapshot('1', bag),
        ),
        1300000,
      );
    },
  );
}
