import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/settings/presentation/screens/settings_screen.dart';

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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
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
}
