import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final _settingsStreamProvider = StreamProvider<AppSetting?>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

/// Resolved settings with defaults applied — the DB row doesn't exist until
/// the user changes something, so every read goes through this.
class ResolvedSettings {
  const ResolvedSettings({
    required this.themeMode,
    required this.taskReminders,
    required this.habitReminders,
    required this.aiInsightAlerts,
  });

  final ThemeMode themeMode;
  final bool taskReminders;
  final bool habitReminders;
  final bool aiInsightAlerts;

  static const defaults = ResolvedSettings(
    themeMode: ThemeMode.system,
    taskReminders: true,
    habitReminders: true,
    aiInsightAlerts: false,
  );
}

ThemeMode _parseThemeMode(String value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String themeModeToValue(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

final settingsProvider = Provider<ResolvedSettings>((ref) {
  final row = ref.watch(_settingsStreamProvider).value;
  if (row == null) return ResolvedSettings.defaults;
  return ResolvedSettings(
    themeMode: _parseThemeMode(row.themeMode),
    taskReminders: row.taskReminders,
    habitReminders: row.habitReminders,
    aiInsightAlerts: row.aiInsightAlerts,
  );
});

class SettingsController {
  SettingsController(this._repo);

  final SettingsRepository _repo;

  Future<void> setThemeMode(ThemeMode mode) =>
      _repo.setThemeMode(themeModeToValue(mode));

  Future<void> setTaskReminders(bool enabled) => _repo.setTaskReminders(enabled);

  Future<void> setHabitReminders(bool enabled) => _repo.setHabitReminders(enabled);

  Future<void> setAiInsightAlerts(bool enabled) => _repo.setAiInsightAlerts(enabled);
}

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});
