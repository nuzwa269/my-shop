import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionVault {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  const SecureSessionVault();
  static const _storage = FlutterSecureStorage();
  static const _key = 'shop_manager_owner_session_v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
