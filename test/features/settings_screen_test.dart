import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/settings/application/app_lock_providers.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/settings/presentation/screens/settings_screen.dart';

class _FakeAppLockService extends AppLockService {
  String? _pin;
  bool biometricsAvailable = false;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<bool> verifyPin(String pin) async => _pin != null && _pin == pin;

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<void> clearPin() async => _pin = null;

  @override
  Future<bool> canUseBiometrics() async => biometricsAvailable;
}

class _FakeNotificationService extends NotificationService {
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({int hour = 20, int minute = 0}) async {
    scheduleCalls++;
  }

  @override
  Future<void> cancelDailyHabitReminder() async {
    cancelCalls++;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeNotificationService notifications;
  late _FakeAppLockService appLock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotificationService();
    appLock = _FakeAppLockService();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
        appLockServiceProvider.overrideWithValue(appLock),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget buildApp() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
    );
  }

  testWidgets('defaults render when no settings row exists yet', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final settings = container.read(settingsProvider);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.taskReminders, isTrue);
    expect(settings.aiInsightAlerts, isFalse);
  });

  testWidgets('changing theme persists and is reflected back through the stream', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

    final row = await db.select(db.appSettings).getSingle();
    expect(row.themeMode, 'dark');
    // Untouched settings must survive a partial upsert.
    expect(row.taskReminders, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('turning off habit reminders cancels the scheduled notification', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Habit reminders'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).habitReminders, isFalse);
    expect(notifications.cancelCalls, 1);

    await tester.tap(find.text('Habit reminders'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).habitReminders, isTrue);
    expect(notifications.scheduleCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('changing currency updates the displayed symbol', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Currency'), 200);
    expect(find.text('₹ · INR'), findsOneWidget);

    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Dollar (USD)'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).currencyCode, 'USD');
    expect(find.text('\$ · USD'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('enabling app lock requires setting a PIN to complete', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();

    // The pin-setup sheet is open — cancel without entering anything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appLockEnabled, isFalse);

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).appLockEnabled, isTrue);
    expect(await appLock.hasPin(), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('disabling app lock requires the correct PIN', (tester) async {
    await appLock.setPin('1234');
    await container.read(settingsControllerProvider).setAppLockEnabled(true);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();

    // Wrong PIN keeps app lock enabled.
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appLockEnabled, isTrue);

    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).appLockEnabled, isFalse);
    expect(await appLock.hasPin(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
