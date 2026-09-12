import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/presentation/screens/habits_overview_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({int hour = 20, int minute = 0}) async {}

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
}

Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const HabitsOverviewScreen(),
      ),
    );
  }

  testWidgets('empty state invites building the first habit', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('No habits yet — build your first one below.'), findsOneWidget);
    expect(find.text('Build a new habit'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('consistency, streak and week dots come from logged history', (
    tester,
  ) async {
    final repo = HabitsRepository(db);
    final id = await repo.createHabit('Morning workout');
    // Two check-ins this week, against the default weekly target.
    final weekStart = startOfWeek(DateTime.now());
    await repo.setCompletedForDate(id, weekStart, true);
    await repo.setCompletedForDate(id, weekStart.add(const Duration(days: 1)), true);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Morning workout'), findsOneWidget);
    // The headline is a real ratio of check-ins to the weekly target, and the
    // caption states both halves of it.
    expect(find.textContaining('check-ins logged this week'), findsOneWidget);
    expect(find.textContaining('2 of'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('the check-off button toggles today and updates the counter', (
    tester,
  ) async {
    final repo = HabitsRepository(db);
    await repo.createHabit('Read 20 pages');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('0 of 1 done'), findsOneWidget);

    // Two add glyphs are on screen: the habit's check-off button and the
    // "Build a new habit" row below the list. The card comes first in the tree.
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pumpAndSettle();

    expect(find.text('1 of 1 done'), findsOneWidget);
    // Toggled state swaps the glyph for a tick.
    expect(find.byIcon(LucideIcons.check), findsOneWidget);

    await _disposeCleanly(tester);
  });
}
