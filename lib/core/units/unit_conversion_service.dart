import '../money/money.dart';
import '../numeric/scaled_integer.dart';
import '../validation/validation.dart';
import 'quantity.dart';

abstract final class UnitConversionService {
  static String code(String text) {
    final result = text.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,23}$').hasMatch(result)) {
      throw const ValidationException(
        'Use a unit code of 1–24 letters, digits, underscores or hyphens.',
      );
    }
    return result;
  }

  /// User defines one unit as an exact decimal count of base units (or kg).
  static UnitConversion define({
    required String unit,
    required String baseUnit,
    required String factor,
    bool factorInKg = false,
  }) {
    final unitCode = code(unit);
    final base = code(baseUnit);
    try {
      var scaled = BigInt.from(Quantity.parse(factor));
      if (factorInKg) {
        if (base != 'gram') {
          throw const ValidationException(
            'kg factors require a gram-based product.',
          );
        }
        scaled *= BigInt.from(1000);
      }
      if (scaled <= BigInt.zero) {
        throw const ValidationException('Conversion factor must be positive.');
      }
      final scale = BigInt.from(Quantity.scale);
      final gcd = scaled.gcd(scale);
      final numerator = ScaledInteger.checked(scaled ~/ gcd);
      final denominator = ScaledInteger.checked(scale ~/ gcd);
      if (numerator > 1000000000 || denominator > 1000000000) {
        throw const ValidationException(
          'Conversion factor exceeds supported precision/range.',
        );
      }
      return UnitConversion(
        unitCode: unitCode,
        baseUnit: base,
        numerator: numerator,
        denominator: denominator,
      );
    } on FormatException {
      throw const ValidationException(
        'Enter a valid factor with at most 6 decimal places.',
      );
    } on ArgumentError {
      throw const ValidationException(
        'Invalid conversion. Gram is 1 gram and kg is 1000 grams.',
      );
    }
  }

  static QuantitySnapshot snapshot(String quantity, UnitConversion conversion) {
    try {
      final amount = Quantity.parse(quantity);
      if (amount <= 0) {
        throw const ValidationException('Quantity must be greater than zero.');
      }
      return QuantitySnapshot(
        originalQuantityScaled: amount,
        conversion: conversion,
      );
    } on FormatException {
      throw const ValidationException(
        'Quantity supports at most 6 decimal places.',
      );
    } on ArgumentError {
      throw const ValidationException(
        'Quantity is too large or cannot be represented exactly.',
      );
    }
  }

  /// Prices retain their own factor; current product-unit edits cannot reinterpret them.
  static int priceTotal({
    required int priceTicks,
    required UnitConversion pricingConversion,
    required QuantitySnapshot quantity,
  }) {
    if (quantity.conversion.baseUnit != pricingConversion.baseUnit ||
        priceTicks < 0) {
      throw const ValidationException(
        'Price and quantity must use the same base unit and a non-negative price.',
      );
    }
    return ScaledInteger.roundRatio(
      BigInt.from(priceTicks) *
          BigInt.from(quantity.baseQuantityScaled) *
          BigInt.from(pricingConversion.denominator),
      BigInt.from(Money.priceScale) *
          BigInt.from(Quantity.scale) *
          BigInt.from(pricingConversion.numerator),
    );
  }

  static UnitConversion fromRow(
    Map<String, Object?> row, {
    String unitKey = 'unit_code',
  }) => UnitConversion(
    unitCode: row[unitKey] as String,
    baseUnit: row['base_unit'] as String,
    numerator: row['conversion_numerator'] as int,
    denominator: row['conversion_denominator'] as int,
  );

  static Map<String, Object?> toRow(UnitConversion conversion) => {
    'unit_code': conversion.unitCode,
    'base_unit': conversion.baseUnit,
    'conversion_numerator': conversion.numerator,
    'conversion_denominator': conversion.denominator,
  };
}
