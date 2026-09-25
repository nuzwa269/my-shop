import '../numeric/scaled_integer.dart';

/// Currency scale is explicit and snapshotted on financial documents.
class Currency {
  Currency(this.code, {required this.minorDigits}) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) ||
        minorDigits < 0 ||
        minorDigits > 4) {
      throw ArgumentError('Invalid currency code or minor-unit precision.');
    }
  }
  static final pkr = Currency('PKR', minorDigits: 2);
  final String code;
  final int minorDigits;
}

abstract final class Money {
  /// One minor unit = 10,000 price ticks (PKR: one tick = 0.000001 PKR).
  static const priceScale = 10000;

  static int parse(String decimal, Currency currency) =>
      ScaledInteger.parse(decimal, decimals: currency.minorDigits);

  static String format(int minorUnits, Currency currency) =>
      ScaledInteger.format(minorUnits, decimals: currency.minorDigits);

  static int parseUnitPrice(String decimal, Currency currency) =>
      ScaledInteger.parse(decimal, decimals: currency.minorDigits + 4);

  /// Prices are per original transaction unit; quantity uses 1,000,000 ticks/unit.
  /// Round once per line, then sum stored line totals. Never round via double.
  static int lineTotal({
    required int unitPriceTicks,
    required int originalQuantityScaled,
  }) => ScaledInteger.roundRatio(
    BigInt.from(unitPriceTicks) * BigInt.from(originalQuantityScaled),
    BigInt.from(priceScale) * BigInt.from(1000000),
  );

  static int sum(Iterable<int> minorAmounts) => ScaledInteger.checked(
    minorAmounts.fold(BigInt.zero, (sum, amount) => sum + BigInt.from(amount)),
  );
}
