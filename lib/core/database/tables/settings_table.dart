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

  /// One of `currency_utils.dart`'s curated `supportedCurrencies` codes.
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  /// Whether app lock is on. The PIN itself is never stored here — it lives
  /// in `flutter_secure_storage`, already OS-encrypted at rest.
  BoolColumn get appLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
