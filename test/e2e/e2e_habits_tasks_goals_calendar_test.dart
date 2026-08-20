import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/calendar/application/calendar_providers.dart';
import 'package:life_manager/features/calendar/data/calendar_repository.dart';
import 'package:life_manager/features/calendar/domain/calendar_item.dart';
import 'package:life_manager/features/goals/application/goals_providers.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/habits/application/habits_providers.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/tasks/application/tasks_providers.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

void main() {
  late AppDatabase db;
  late HabitsRepository habitsRepo;
  late TasksRepository tasksRepo;
  late GoalsRepository goalsRepo;
  late CalendarRepository calendarRepo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    habitsRepo = HabitsRepository(db);
    tasksRepo = TasksRepository(db);
    goalsRepo = GoalsRepository(db);
    calendarRepo = CalendarRepository(db);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        habitsRepositoryProvider.overrideWithValue(habitsRepo),
        tasksRepositoryProvider.overrideWithValue(tasksRepo),
        goalsRepositoryProvider.overrideWithValue(goalsRepo),
        calendarRepositoryProvider.overrideWithValue(calendarRepo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('E2E Habits, Tasks, Goals & Calendar Lifecycle & Edge Cases', () {
    test('habit streaks, missed days, multiple logs, and weekly completion matrix', () async {
      // Keep provider listened from start
      container.listen(habitsWithProgressProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final habitId = await habitsRepo.createHabit('Hydration Routine');

      final today = dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final fourDaysAgo = today.subtract(const Duration(days: 4)); // 3 days ago missing -> break

      // 1. Log two days ago, yesterday, and today -> Streak should be 3
      await habitsRepo.setCompletedForDate(habitId, twoDaysAgo, true);
      await habitsRepo.setCompletedForDate(habitId, yesterday, true);
      await habitsRepo.setCompletedForDate(habitId, today, true);
      await Future.delayed(const Duration(milliseconds: 50));

      final habitsWithProg = container.read(habitsWithProgressProvider);
      expect(habitsWithProg, hasLength(1));
      expect(habitsWithProg.first.streakDays, 3);
      expect(habitsWithProg.first.isAtRisk, isFalse);

      // 2. Untoggle today -> Streak is still 2 (from yesterday and two days ago) but isAtRisk becomes true!
      await habitsRepo.setCompletedForDate(habitId, today, false);
      await Future.delayed(const Duration(milliseconds: 50));

      final progressAfterUntoggle = container.read(habitsWithProgressProvider);
      expect(progressAfterUntoggle.first.streakDays, 2);
      expect(progressAfterUntoggle.first.isAtRisk, isTrue);

      // 3. Untoggle yesterday -> Streak resets to 0 (since neither today nor yesterday is completed)
      await habitsRepo.setCompletedForDate(habitId, yesterday, false);
      await Future.delayed(const Duration(milliseconds: 50));

      final progressReset = container.read(habitsWithProgressProvider);
      expect(progressReset.first.streakDays, 0);

      // 4. Log four days ago -> streak remains 0 because gap exists
      await habitsRepo.setCompletedForDate(habitId, fourDaysAgo, true);
      await Future.delayed(const Duration(milliseconds: 50));

      final progressGap = container.read(habitsWithProgressProvider);
      expect(progressGap.first.streakDays, 0);
    });

    test('goals with linked habits and milestone checklist progress', () async {
      container.listen(goalsWithLinksProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Create a Goal
      final goalId = await goalsRepo.createGoal(
        title: 'Marathon 2026',
        targetValue: 42,
        currentValue: 10,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      );

      // 2. Add Milestones to the Goal
      final milestone1Id = await goalsRepo.createMilestone(goalId: goalId, title: 'Run 10km without stopping');
      final milestone2Id = await goalsRepo.createMilestone(goalId: goalId, title: 'Run 21km Half Marathon');

      // 3. Link a Habit to the Goal
      final habitId = await habitsRepo.createHabit('Daily 5km Jog');
      await goalsRepo.addLink(goalId: goalId, linkedType: 'habit', linkedId: habitId);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify goal with links
      final goals = container.read(goalsWithLinksProvider);
      expect(goals, hasLength(1));
      expect(goals.first.goal.id, goalId);
      expect(goals.first.links.map((l) => l.label), contains('Daily 5km Jog'));

      final milestones = await goalsRepo.watchMilestonesForGoal(goalId).first;
      expect(milestones, hasLength(2));
      expect(milestones.every((m) => !m.completed), isTrue);

      // Toggle milestone 1 completed
      await goalsRepo.setMilestoneCompleted(milestone1Id, true);
      final updatedMilestones = await goalsRepo.watchMilestonesForGoal(goalId).first;
      expect(updatedMilestones.firstWhere((m) => m.id == milestone1Id).completed, isTrue);
      expect(updatedMilestones.firstWhere((m) => m.id == milestone2Id).completed, isFalse);

      // Update goal progress value
      await goalsRepo.updateProgress(goalId, 25);
      final updatedGoal = await goalsRepo.getGoal(goalId);
      expect(updatedGoal?.currentValue, 25);
    });

    test('polymorphic calendar aggregation across tasks, habits, and manual events without duplication', () async {
      final targetDate = dateOnly(DateTime.now().add(const Duration(days: 1)));

      // Set calendar selected day to targetDate
      container.read(selectedCalendarDayProvider.notifier).select(targetDate);
      container.listen(selectedDayItemsProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Insert standalone Event
      final eventId = await db.into(db.events).insertReturning(
        EventsCompanion.insert(
          title: 'Project Kickoff Meeting',
          startTime: targetDate.add(const Duration(hours: 10)),
          endTime: Value(targetDate.add(const Duration(hours: 11))),
        ),
      );

      // 2. Insert Task due on targetDate
      final taskId = await tasksRepo.createTask(
        title: 'Review PR Specs',
        dueDate: targetDate.add(const Duration(hours: 14)),
        priority: 'high',
      );

      // 3. Insert Habit and log completion on targetDate
      final habitId = await habitsRepo.createHabit('Deep Reading');
      await habitsRepo.setCompletedForDate(habitId, targetDate, true);

      // 4. Insert Unpaid Bill due on targetDate
      final bill = await db.into(db.bills).insertReturning(
        BillsCompanion.insert(
          name: 'Cloud Hosting',
          amountMinor: 250000,
          dueDate: targetDate,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Query raw database Events table to ensure NO duplicate rows were created for task/habit
      final rawEvents = await db.select(db.events).get();
      expect(rawEvents, hasLength(1));
      expect(rawEvents.single.id, eventId.id);

      // Query calendar aggregated view
      final dayItems = container.read(selectedDayItemsProvider);
      expect(dayItems, hasLength(4));

      final types = dayItems.map((i) => i.type).toSet();
      expect(types, contains(CalendarItemType.event));
      expect(types, contains(CalendarItemType.task));
      expect(types, contains(CalendarItemType.habit));
      expect(types, contains(CalendarItemType.bill));

      // Verify source IDs map cleanly
      expect(dayItems.firstWhere((i) => i.type == CalendarItemType.event).sourceId, eventId.id);
      expect(dayItems.firstWhere((i) => i.type == CalendarItemType.task).sourceId, taskId);
      expect(dayItems.firstWhere((i) => i.type == CalendarItemType.habit).sourceId, habitId);
      expect(dayItems.firstWhere((i) => i.type == CalendarItemType.bill).sourceId, bill.id);

      // Edge case: Delete the task -> calendar should cleanly update to 3 items
      await tasksRepo.deleteTask(taskId);
      await Future.delayed(const Duration(milliseconds: 50));

      final updatedItems = container.read(selectedDayItemsProvider);
      expect(updatedItems, hasLength(3));
      expect(updatedItems.any((i) => i.type == CalendarItemType.task), isFalse);
    });
  });
}
