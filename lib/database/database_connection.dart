/// Persistence boundary for future feature repositories.
/// SQL and storage rows stay in data layers; widgets use providers/use cases.
abstract interface class SqlSession {
  Future<void> execute(String sql, [List<Object?> arguments = const []]);
  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> arguments = const [],
  ]);
}

abstract interface class DatabaseConnection implements SqlSession {
  Future<T> transaction<T>(Future<T> Function(SqlSession session) action);
  Future<void> close();
}
