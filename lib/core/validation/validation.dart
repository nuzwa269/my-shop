class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class Validation {
  static String requiredText(String value, String label, {int max = 120}) {
    final text = value.trim();
    if (text.isEmpty || text.length > max) {
      throw ValidationException(
        '$label is required (maximum $max characters).',
      );
    }
    return text;
  }

  static String key(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  static String? optional(String value, {int max = 500}) {
    if (value.trim().length > max) {
      throw ValidationException('Text is too long (maximum $max characters).');
    }
    return value.trim().isEmpty ? null : value.trim();
  }

  static String username(String value) {
    final result = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9._@+-]{2,99}$').hasMatch(result)) {
      throw const ValidationException(
        'Use a username or email of 3–100 characters without spaces.',
      );
    }
    return result;
  }

  static void password(String value) {
    final isPin = RegExp(r'^\d{6,12}$').hasMatch(value);
    if (!isPin && (value.trim().length < 12 || value.length > 128)) {
      throw const ValidationException(
        'Use a 6–12 digit PIN or a password of 12–128 characters.',
      );
    }
  }
}
