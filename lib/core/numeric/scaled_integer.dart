/// All persisted numeric values fit SQLite's signed 64-bit INTEGER.
/// BigInt intermediates prevent multiplication overflow before range checking.
abstract final class ScaledInteger {
  static final BigInt _min = -(BigInt.one << 63);
  static final BigInt _max = (BigInt.one << 63) - BigInt.one;

  static int checked(BigInt value) {
    if (value < _min || value > _max) {
      throw RangeError('Value exceeds SQLite signed 64-bit range.');
    }
    return value.toInt();
  }

  /// Strict decimal parsing: no exponent, locale separator, or silent truncation.
  static int parse(String text, {required int decimals}) {
    if (decimals < 0 || decimals > 12) {
      throw ArgumentError.value(decimals, 'decimals');
    }
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(text.trim());
    if (match == null) throw FormatException('Invalid decimal', text);
    final fraction = match.group(3) ?? '';
    if (fraction.length > decimals) {
      throw FormatException(
        'At most $decimals decimal places are supported',
        text,
      );
    }
    final scale = BigInt.from(10).pow(decimals);
    final magnitude =
        BigInt.parse(match.group(2)!) * scale +
        BigInt.parse(
          fraction.padRight(decimals, '0').isEmpty
              ? '0'
              : fraction.padRight(decimals, '0'),
        );
    return checked(match.group(1) == '-' ? -magnitude : magnitude);
  }

  static String format(int value, {required int decimals}) {
    if (decimals < 0 || decimals > 12) {
      throw ArgumentError.value(decimals, 'decimals');
    }
    final magnitude = BigInt.from(value).abs();
    final sign = value < 0 ? '-' : '';
    if (decimals == 0) return '$sign$magnitude';
    final digits = magnitude.toString().padLeft(decimals + 1, '0');
    final split = digits.length - decimals;
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }

  /// Round exact rational values to nearest integer; ties away from zero.
  static int roundRatio(BigInt numerator, BigInt denominator) {
    if (denominator <= BigInt.zero) {
      throw ArgumentError('Denominator must be positive.');
    }
    final magnitude = numerator.abs();
    var quotient = magnitude ~/ denominator;
    if ((magnitude % denominator) * BigInt.two >= denominator) {
      quotient += BigInt.one;
    }
    return checked(numerator.isNegative ? -quotient : quotient);
  }
}
