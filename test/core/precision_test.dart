import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/money/money.dart';
import 'package:shop_manager/core/numeric/scaled_integer.dart';
import 'package:shop_manager/core/units/quantity.dart';

void main() {
  group('Money', () {
    test('PKR minor units preserve decimals without floating point', () {
      expect(Money.parse('1234.56', Currency.pkr), 123456);
      expect(Money.format(-123456, Currency.pkr), '-1234.56');
      expect(Money.parse('0.01', Currency.pkr), 1);
      expect(() => Money.parse('1.001', Currency.pkr), throwsFormatException);
      expect(() => Money.parse('1e3', Currency.pkr), throwsFormatException);
      expect(() => Money.parse('1,200', Currency.pkr), throwsFormatException);
    });
    test('line rounding is symmetric, nearest with ties away from zero', () {
      final price = Money.parseUnitPrice('0.01', Currency.pkr);
      expect(
        Money.lineTotal(
          unitPriceTicks: price,
          originalQuantityScaled: Quantity.parse('0.5'),
        ),
        1,
      );
      expect(
        Money.lineTotal(
          unitPriceTicks: price,
          originalQuantityScaled: Quantity.parse('-0.5'),
        ),
        -1,
      );
      expect(
        Money.lineTotal(
          unitPriceTicks: price,
          originalQuantityScaled: Quantity.parse('0.499999'),
        ),
        0,
      );
      expect(
        Money.lineTotal(
          unitPriceTicks: Money.parseUnitPrice('125.555555', Currency.pkr),
          originalQuantityScaled: Quantity.parse('2.5'),
        ),
        31389,
      );
      expect(Money.sum([1, 1, -1]), 1);
    });
    test('BigInt intermediates and SQLite limits are checked', () {
      final max = (BigInt.one << 63) - BigInt.one;
      expect(
        ScaledInteger.parse('9223372036854775807', decimals: 0),
        max.toInt(),
      );
      expect(() => Money.sum([max.toInt(), 1]), throwsRangeError);
      expect(
        () => ScaledInteger.parse('9223372036854775808', decimals: 0),
        throwsRangeError,
      );
      expect(
        ScaledInteger.format((-BigInt.one << 63).toInt(), decimals: 2),
        '-92233720368547758.08',
      );
      expect(
        Money.lineTotal(
          unitPriceTicks: 100000000000000,
          originalQuantityScaled: 1000000000000,
        ),
        10000000000000000,
      );
    });
  });
  group('Quantities', () {
    test('grams are canonical and fractional grams are exact', () {
      expect(
        UnitConversion.kilograms().normalize(Quantity.parse('1')),
        Quantity.parse('1000'),
      );
      expect(
        UnitConversion.kilograms().normalize(Quantity.parse('0.000001')),
        Quantity.parse('0.001'),
      );
      expect(UnitConversion.grams().normalize(Quantity.parse('0.125')), 125000);
      expect(() => Quantity.parse('0.0000001'), throwsFormatException);
    });
    test(
      'bag conversion belongs to a product snapshot, not a global default',
      () {
        final a = UnitConversion(
          unitCode: 'bag',
          baseUnit: 'gram',
          numerator: 25000,
          denominator: 1,
        );
        final b = UnitConversion(
          unitCode: 'bag',
          baseUnit: 'gram',
          numerator: 50000,
          denominator: 1,
        );
        final original = Quantity.parse('2');
        expect(a.normalize(original), Quantity.parse('50000'));
        expect(b.normalize(original), Quantity.parse('100000'));
        final snapshot = QuantitySnapshot(
          originalQuantityScaled: original,
          conversion: a,
        );
        final restored = QuantitySnapshot.fromRow(snapshot.toRow());
        expect(restored.conversion.unitCode, 'bag');
        expect(restored.originalQuantityScaled, original);
        expect(restored.baseQuantityScaled, Quantity.parse('50000'));
        expect(
          () => QuantitySnapshot.fromRow({
            ...snapshot.toRow(),
            'base_quantity_scaled': 1,
          }),
          throwsStateError,
        );
      },
    );
    test(
      'custom units require explicit positive factors and exact normalization',
      () {
        expect(
          () => UnitConversion(
            unitCode: 'maund',
            baseUnit: 'gram',
            numerator: 0,
            denominator: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => UnitConversion(
            unitCode: 'kg',
            baseUnit: 'gram',
            numerator: 100,
            denominator: 1,
          ),
          throwsArgumentError,
        );
        final thirds = UnitConversion(
          unitCode: 'piece',
          baseUnit: 'custom',
          numerator: 1,
          denominator: 3,
        );
        expect(() => thirds.normalize(1), throwsArgumentError);
        expect(thirds.normalize(3), 1);
        expect(
          () => UnitConversion.kilograms().normalize(9223372036854775807),
          throwsRangeError,
        );
      },
    );
  });
}
