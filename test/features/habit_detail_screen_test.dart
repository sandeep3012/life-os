import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/presentation/screens/habit_detail_screen.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

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

void main() {
  late AppDatabase db;
  late String habitId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitsRepository(db);
    habitId = await repo.createHabit('Morning workout');
    await repo.setCompletedForDate(habitId, DateTime.now(), true, notes: 'felt great');
  });

  tearDown(() => db.close());

  /// Pushes the detail screen on top of a placeholder host (mirroring how
  /// go_router pushes it as a nested route in the real app) so `pop()`
  /// after archiving has somewhere to land, instead of being the app's only
  /// route.
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habitId)),
                ),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders habit name, streak, and seeded log history', (tester) async {
    await openDetail(tester);

    expect(find.text('Morning workout'), findsWidgets);
    expect(find.textContaining('day streak'), findsOneWidget);
    expect(find.text('felt great'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('editing a log note persists the change', (tester) async {
    await openDetail(tester);

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'updated note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('updated note'), findsOneWidget);
    expect(find.text('felt great'), findsNothing);

    await _disposeCleanly(tester);
  });

  testWidgets('archiving navigates back and removes the habit from the list', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Archive habit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();

    // Back at the host screen — the detail screen's own content is gone.
    expect(find.text('open detail'), findsOneWidget);
    expect(find.text('Archive habit'), findsNothing);

    // Real async DB I/O outside the widget tree needs the real zone —
    // awaiting it directly in the fake-async test zone can deadlock.
    await tester.runAsync(() async {
      final repo = HabitsRepository(db);
      final remaining = await repo.watchHabits().first;
      expect(remaining.map((h) => h.id), isNot(contains(habitId)));
    });

    await _disposeCleanly(tester);
  });

  testWidgets(
    'an already-archived habit shows Restore, keeps its category, and can be unarchived',
    (tester) async {
      final repo = HabitsRepository(db);
      final category = await repo.createHabitCategory(
        name: 'Fitness',
        icon: 'fitness_center',
        colorHex: '#2E9E63',
      );
      final archivedId = await repo.createHabit('Old routine', categoryId: category.id);
      await repo.archiveHabit(archivedId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: HabitDetailScreen(habitId: archivedId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habit not found'), findsNothing);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Restore habit'), findsOneWidget);
      expect(find.text('Archive habit'), findsNothing);

      await tester.tap(find.text('Restore habit'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final active = await repo.watchHabits().first;
        expect(active.map((h) => h.id), contains(archivedId));
      });

      await _disposeCleanly(tester);
    },
  );
}

/// See the identical helper in `tasks_habits_screen_test.dart` — forces
/// Drift's stream-cancellation cleanup timer to fire inside the test body.
Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
