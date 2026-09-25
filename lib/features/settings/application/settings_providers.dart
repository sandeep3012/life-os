import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_color_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/settings_repository.dart';

enum SaveFeedbackMode { animation, confirmation }

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
    this.hapticsEnabled = true,
    this.saveAnimationsEnabled = true,
    this.saveConfirmationsEnabled = false,
    required this.themeMode,
    required this.colorTheme,
    required this.transactionEntryLayout,
    required this.taskReminders,
    required this.habitReminders,
    required this.aiInsightAlerts,
    required this.currencyCode,
    required this.appLockEnabled,
    required this.biometricEnabled,
    this.balancesVisible = true,
  });

  final ThemeMode themeMode;
  final bool hapticsEnabled;
  final bool saveAnimationsEnabled;
  final bool saveConfirmationsEnabled;
  final AppColorTheme colorTheme;
  final String transactionEntryLayout;
  final bool taskReminders;
  final bool habitReminders;
  final bool aiInsightAlerts;
  final String currencyCode;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool balancesVisible;

  static const defaults = ResolvedSettings(
    themeMode: ThemeMode.system,
    colorTheme: AppColorTheme.forest,
    transactionEntryLayout: 'keypad',
    taskReminders: true,
    habitReminders: true,
    aiInsightAlerts: false,
    currencyCode: 'INR',
    appLockEnabled: false,
    biometricEnabled: false,
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

/// Whether the stored settings have actually been read yet.
///
/// [settingsProvider] can't express this: it collapses "still loading" and
/// "loaded, nothing saved" into the same defaults, which is right for every
/// caller except the one that picks the theme. An error counts as loaded —
/// defaults are then the honest answer, and blocking the app on an
/// unreadable settings row would be worse than showing it in green.
final settingsLoadedProvider = Provider<bool>((ref) {
  final row = ref.watch(_settingsStreamProvider);
  return row.hasValue || row.hasError;
});

final settingsProvider = Provider<ResolvedSettings>((ref) {
  final row = ref.watch(_settingsStreamProvider).value;
  if (row == null) return ResolvedSettings.defaults;
  return ResolvedSettings(
    hapticsEnabled: row.hapticsEnabled,
    saveAnimationsEnabled: row.saveAnimationsEnabled,
    saveConfirmationsEnabled: row.saveConfirmationsEnabled,
    themeMode: _parseThemeMode(row.themeMode),
    colorTheme: appColorThemeFromStorage(row.colorTheme),
    transactionEntryLayout: row.transactionEntryLayout,
    taskReminders: row.taskReminders,
    habitReminders: row.habitReminders,
    aiInsightAlerts: row.aiInsightAlerts,
    currencyCode: row.currencyCode,
    appLockEnabled: row.appLockEnabled,
    biometricEnabled: row.biometricEnabled,
    balancesVisible: row.balancesVisible,
  );
});

class SettingsController {
  SettingsController(this._repo);

  final SettingsRepository _repo;

  Future<void> setHapticsEnabled(bool enabled) =>
      _repo.setHapticsEnabled(enabled);
  Future<void> setSaveAnimationsEnabled(bool enabled) =>
      _repo.setSaveAnimationsEnabled(enabled);
  Future<void> setSaveFeedbackMode(SaveFeedbackMode mode) =>
      _repo.setSaveFeedbackMode(
        animation: mode == SaveFeedbackMode.animation,
        confirmation: mode == SaveFeedbackMode.confirmation,
      );
  Future<void> setSaveFeedbackEnabled(bool enabled) =>
      _repo.setSaveFeedbackEnabled(enabled);

  Future<void> setThemeMode(ThemeMode mode) =>
      _repo.setThemeMode(themeModeToValue(mode));

  Future<void> setColorTheme(AppColorTheme theme) =>
      _repo.setColorTheme(theme.storageValue);

  Future<void> setTransactionEntryLayout(String layout) =>
      _repo.setTransactionEntryLayout(layout);

  Future<void> setBalancesVisible(bool visible) =>
      _repo.setBalancesVisible(visible);

  Future<void> setTaskReminders(bool enabled) =>
      _repo.setTaskReminders(enabled);

  Future<void> setHabitReminders(bool enabled) =>
      _repo.setHabitReminders(enabled);

  Future<void> setAiInsightAlerts(bool enabled) =>
      _repo.setAiInsightAlerts(enabled);

  Future<void> setCurrencyCode(String code) => _repo.setCurrencyCode(code);

  Future<void> setAppLockEnabled(bool enabled) =>
      _repo.setAppLockEnabled(enabled);

  Future<void> setBiometricEnabled(bool enabled) =>
      _repo.setBiometricEnabled(enabled);
}

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});
