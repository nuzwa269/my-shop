import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../domain/password_hasher.dart';

class Pbkdf2PasswordHasher implements PasswordHasher {
  const Pbkdf2PasswordHasher();
  static const iterations = 600000;

  @override
  Future<String> hash(String password) => Isolate.run(() async {
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256));
    final bytes = await derive(password, salt, iterations);
    return [
      'pbkdf2-sha256',
      'v1',
      '$iterations',
      base64Encode(salt),
      base64Encode(bytes),
    ].join(':');
  });

  @override
  Future<bool> verify(String password, String encoded) => Isolate.run(() async {
    try {
      final parts = encoded.split(':');
      if (parts.length != 5 ||
          parts[0] != 'pbkdf2-sha256' ||
          parts[1] != 'v1') {
        return false;
      }
      final work = int.parse(parts[2]);
      if (work < iterations || work > 2000000) return false;
      final salt = base64Decode(parts[3]);
      final expected = base64Decode(parts[4]);
      if (salt.length != 16 || expected.length != 32) return false;
      final actual = await derive(password, salt, work);
      var difference = 0;
      for (var i = 0; i < expected.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  });

  static Future<List<int>> derive(
    String password,
    List<int> salt,
    int work,
  ) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: work,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return key.extractBytes();
  }
}
