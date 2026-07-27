import 'package:drift/drift.dart';

/// Single-row table (id is always 0) for the Settings screen's toggles —
/// this app has no accounts, so app-wide preferences live in one row rather
/// than per-user.
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// light | dark | system
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get taskReminders => boolean().withDefault(const Constant(true))();
  BoolColumn get habitReminders =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get aiInsightAlerts =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
