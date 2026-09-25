abstract interface class PasswordHasher {
  Future<String> hash(String password);
  Future<bool> verify(String password, String encoded);
}
