import 'package:drift/drift.dart';

/// Single-row table (id is always 0) for the Settings screen's toggles —
/// this app has no accounts, so app-wide preferences live in one row rather
/// than per-user.
class AppSettings extends Table {
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get saveAnimationsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get saveConfirmationsEnabled =>
      boolean().withDefault(const Constant(false))();

  IntColumn get id => integer().withDefault(const Constant(0))();

  /// light | dark | system
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  /// Selected curated color palette, independent of [themeMode].
  TextColumn get colorTheme => text().withDefault(const Constant('forest'))();

  /// keypad | form — the transaction recorder layout last selected by the user.
  TextColumn get transactionEntryLayout =>
      text().withDefault(const Constant('keypad'))();
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

  /// Whether Finance home shows its balances. Off masks the running total and
  /// every account card, for reading the app in public.
  BoolColumn get balancesVisible =>
      boolean().withDefault(const Constant(true))();

  /// The in-app "Animations: Reduced" choice. Applies the phone's own
  /// reduce-motion behaviour to LifeOS alone; the phone's setting, when on,
  /// still wins regardless of this.
  BoolColumn get reduceMotion => boolean().withDefault(const Constant(false))();

  /// The large screen transitions — circle reveals, the page turn and the
  /// tab content slide. Off swaps them for a short fade while every other
  /// animation keeps playing.
  BoolColumn get transitionEffectsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// The first-launch welcome screens have been finished or skipped.
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  /// Comma-separated ids of the screen tours already shown (e.g. `home`).
  /// Settings → "Replay the tour" clears it.
  TextColumn get toursSeen => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
