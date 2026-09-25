import '../numeric/scaled_integer.dart';

/// A million ticks represent one gram (weight) or one explicit custom base unit.
abstract final class Quantity {
  static const scale = 1000000;
  static int parse(String decimal) => ScaledInteger.parse(decimal, decimals: 6);
  static String format(int scaled) => ScaledInteger.format(scaled, decimals: 6);
  static String formatDisplay(int scaled) {
    final value = format(scaled);
    if (!value.contains('.')) return value;
    final compact = value
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return compact;
  }
}

class UnitConversion {
  UnitConversion({
    required this.unitCode,
    required this.baseUnit,
    required this.numerator,
    required this.denominator,
  }) {
    if (unitCode.trim().isEmpty ||
        baseUnit.trim().isEmpty ||
        numerator <= 0 ||
        denominator <= 0) {
      throw ArgumentError(
        'A named unit and positive explicit factor are required.',
      );
    }
    if (unitCode == 'kg' &&
        (baseUnit != 'gram' ||
            BigInt.from(numerator) !=
                BigInt.from(denominator) * BigInt.from(1000))) {
      throw ArgumentError('kg must convert to grams at 1000:1.');
    }
    if (unitCode == 'gram' &&
        (baseUnit != 'gram' || numerator != denominator)) {
      throw ArgumentError('gram must convert to grams at 1:1.');
    }
  }

  factory UnitConversion.grams() => UnitConversion(
    unitCode: 'gram',
    baseUnit: 'gram',
    numerator: 1,
    denominator: 1,
  );
  factory UnitConversion.kilograms() => UnitConversion(
    unitCode: 'kg',
    baseUnit: 'gram',
    numerator: 1000,
    denominator: 1,
  );

  final String unitCode;
  final String baseUnit;

  /// Base units per original unit, represented as an exact rational factor.
  final int numerator;
  final int denominator;

  /// Compact exact factor for user-facing text; persisted factors stay rational.
  String get displayFactor =>
      denominator == 1 ? '$numerator' : '$numerator/$denominator';

  /// Reject sub-resolution quantities instead of silently losing physical stock.
  int normalize(int originalQuantityScaled) {
    final result = BigInt.from(originalQuantityScaled) * BigInt.from(numerator);
    final divisor = BigInt.from(denominator);
    if (result % divisor != BigInt.zero) {
      throw ArgumentError(
        'Quantity is below the supported base-unit precision.',
      );
    }
    return ScaledInteger.checked(result ~/ divisor);
  }
}

class QuantitySnapshot {
  QuantitySnapshot({
    required this.originalQuantityScaled,
    required this.conversion,
  }) : baseQuantityScaled = conversion.normalize(originalQuantityScaled);

  final int originalQuantityScaled;
  final UnitConversion conversion;
  final int baseQuantityScaled;

  Map<String, Object?> toRow() => {
    'original_quantity_scaled': originalQuantityScaled,
    'original_unit_code': conversion.unitCode,
    'base_unit': conversion.baseUnit,
    'conversion_numerator': conversion.numerator,
    'conversion_denominator': conversion.denominator,
    'base_quantity_scaled': baseQuantityScaled,
  };

  factory QuantitySnapshot.fromRow(Map<String, Object?> row) {
    final result = QuantitySnapshot(
      originalQuantityScaled: row['original_quantity_scaled'] as int,
      conversion: UnitConversion(
        unitCode: row['original_unit_code'] as String,
        baseUnit: row['base_unit'] as String,
        numerator: row['conversion_numerator'] as int,
        denominator: row['conversion_denominator'] as int,
      ),
    );
    if (result.baseQuantityScaled != row['base_quantity_scaled']) {
      throw StateError(
        'Stored quantity does not match its conversion snapshot.',
      );
    }
    return result;
  }
}
