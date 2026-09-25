import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_connection.dart';
import 'sqlite_database.dart';

final databaseProvider = FutureProvider<DatabaseConnection>((ref) async {
  final opening = SqliteDatabase.open();
  ref.onDispose(() {
    unawaited(
      opening.then((db) => db.close(), onError: (Object _, StackTrace _) {}),
    );
  });
  return opening;
});
