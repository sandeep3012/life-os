import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/onboarding/application/onboarding_gate.dart';

class _FakeNotificationService extends NotificationService {
  int permissionRequests = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestReminderPermissions() async => permissionRequests++;

  @override
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {}

  @override
  Future<void> cancelDailyHabitReminder() async {}

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}
}

void main() {
  late AppDatabase db;
  late _FakeNotificationService notifications;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotificationService();
  });

  tearDown(() async {
    OnboardingGate.debugOffer = false;
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const LifeOSApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<AppSetting> settings() => db.select(db.appSettings).getSingle();

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a first launch walks through setup, then tours Home', (
    tester,
  ) async {
    OnboardingGate.debugOffer = true;
    await pumpApp(tester);

    expect(find.textContaining('Your whole day'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Private by design.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Setup choices are saved as they're picked.
    await tester.tap(find.text('USD \$'));
    await tester.pumpAndSettle();
    expect((await settings()).currencyCode, 'USD');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a thing.'), findsOneWidget);

    await tester.tap(find.text('Turn on reminders'));
    await tester.pumpAndSettle();

    // Permission is asked here, with the reason on screen.
    expect(notifications.permissionRequests, 1);
    expect((await settings()).onboardingCompleted, isTrue);

    // Home, with its tour on top.
    expect(find.text('Add anything from here'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Everything else lives here'), findsOneWidget);
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();

    expect(find.text('Everything else lives here'), findsNothing);
    expect((await settings()).toursSeen, 'home');
    await disposeCleanly(tester);
  });

  testWidgets('Skip jumps straight to setup', (tester) async {
    OnboardingGate.debugOffer = true;
    await pumpApp(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Make it yours.'), findsOneWidget);
    await disposeCleanly(tester);
  });

  testWidgets('Start fresh finishes without asking for permission', (
    tester,
  ) async {
    OnboardingGate.debugOffer = true;
    await pumpApp(tester);
    for (final label in ['Next', 'Next', 'Continue']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start fresh'));
    await tester.pumpAndSettle();

    expect(notifications.permissionRequests, 0);
    expect((await settings()).onboardingCompleted, isTrue);
    await disposeCleanly(tester);
  });

  testWidgets('a seen tour stays away; outside a real launch nothing shows', (
    tester,
  ) async {
    await db
        .into(db.appSettings)
        .insert(
          const AppSettingsCompanion(
            id: Value(0),
            onboardingCompleted: Value(true),
            toursSeen: Value('home'),
          ),
        );
    OnboardingGate.debugOffer = true;
    await pumpApp(tester);
    expect(find.text('Add anything from here'), findsNothing);
    expect(find.textContaining('Your whole day'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('tests and in-app restarts never get onboarding', (
    tester,
  ) async {
    // debugOffer stays off: this is what every other app test sees.
    await pumpApp(tester);
    expect(find.textContaining('Your whole day'), findsNothing);
    await disposeCleanly(tester);
  });
}
