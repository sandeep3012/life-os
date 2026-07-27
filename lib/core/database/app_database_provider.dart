import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Single shared [AppDatabase] instance for the whole app — every feature
/// repository reads this instead of constructing its own connection, since
/// cross-module screens (Calendar, AI Analyser) need to query across tables
/// that different modules own.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
