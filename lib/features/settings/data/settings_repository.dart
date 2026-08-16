import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Reads/writes the single [AppSettings] row (id 0). The row is created
/// lazily on first write, so a fresh install just falls back to defaults.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSetting?> watchSettings() {
    return (_db.select(_db.appSettings)..where((s) => s.id.equals(0)))
        .watchSingleOrNull();
  }

  Future<void> _upsert(AppSettingsCompanion companion) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(companion.copyWith(id: const Value(0)));
  }

  Future<void> setThemeMode(String mode) => _upsert(
    AppSettingsCompanion(themeMode: Value(mode)),
  );

  Future<void> setTaskReminders(bool enabled) => _upsert(
    AppSettingsCompanion(taskReminders: Value(enabled)),
  );

  Future<void> setHabitReminders(bool enabled) => _upsert(
    AppSettingsCompanion(habitReminders: Value(enabled)),
  );

  Future<void> setAiInsightAlerts(bool enabled) => _upsert(
    AppSettingsCompanion(aiInsightAlerts: Value(enabled)),
  );

  Future<void> setCurrencyCode(String code) => _upsert(
    AppSettingsCompanion(currencyCode: Value(code)),
  );

  Future<void> setAppLockEnabled(bool enabled) => _upsert(
    AppSettingsCompanion(appLockEnabled: Value(enabled)),
  );

  Future<void> setBiometricEnabled(bool enabled) => _upsert(
    AppSettingsCompanion(biometricEnabled: Value(enabled)),
  );
}
