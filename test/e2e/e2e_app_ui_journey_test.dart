import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({int hour = 20, int minute = 0}) async {}

  @override
  Future<void> cancelDailyHabitReminder() async {}

  @override
  Future<void> scheduleEventReminder({
    required String eventId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelEventReminder(String eventId) async {}

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}

  @override
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String title,
    required int hour,
    required int minute,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelHabitReminder(String habitId) async {}

  @override
  Future<void> scheduleGoalReminder({
    required String goalId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelGoalReminder(String goalId) async {}
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('e2e_ui_journey_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('full app UI navigation and journey test across bottom navigation bars and tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
        ],
        child: const LifeOSApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. App starts on Home dashboard
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Your dashboard fills in as you go'), findsOneWidget);

    // 2. Navigate to Finance tab
    await tester.tap(find.text('Finance'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);

    // 3. Navigate to Tasks tab
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);

    // 4. Navigate to Calendar tab
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);

    // 5. Navigate to More tab
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);

    // 6. Navigate back to Home
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Your dashboard fills in as you go'), findsOneWidget);

    // Clean disposal
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
