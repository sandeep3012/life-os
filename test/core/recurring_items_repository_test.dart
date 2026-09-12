import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/domain/habit_schedule.dart';
import 'package:life_manager/features/calendar/data/calendar_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('task completion and repeated generation preserve fixed dates and totals', () async {
    final repo = TasksRepository(db);
    final start = RepeatSchedule.day(DateTime.now());
    final end = DateTime(start.year, start.month, start.day + 4);
    final id = await repo.createTask(title: 'Read', description: 'Ten pages',
      schedule: RepeatSchedule(start: start, frequency: 'daily', end: end));
    final before = await repo.watchAllTasks().first;
    expect(before.length, 5);
    expect(before.every((t) => t.description == 'Ten pages'), isTrue);
    await repo.setTaskDone(id, true);
    await repo.extendRecurringTasks();
    await repo.extendRecurringTasks();
    final after = await repo.watchAllTasks().first;
    expect(after.length, 5);
    expect(after.where((t) => t.status == 'done').length, 1);
    expect(after.map((t) => t.dueDate), before.map((t) => t.dueDate));
  });
  test('weekly tasks begin on a selected day, not an unselected start day', () async {
    final start = RepeatSchedule.day(DateTime.now());
    final next = DateTime(start.year, start.month, start.day + 1);
    final repo = TasksRepository(db);
    await repo.createTask(title: 'Weekly', schedule: RepeatSchedule(
      start: start, frequency: 'weekly', weekdays: [next.weekday], end: next));
    expect((await repo.watchAllTasks().first).single.dueDate, next);
  });
  test('event description is copied and inclusive end retains final occurrence', () async {
    final repo = CalendarRepository(db);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 18);
    final end = DateTime(today.year, today.month, today.day + 2);
    await repo.createEvent(title: 'Practice', description: 'Bring notes', startTime: start,
      schedule: RepeatSchedule(start: start, frequency: 'daily', end: end));
    await repo.extendRecurringEvents();
    final events = await repo.watchManualEvents().first;
    expect(events.length, 3);
    expect(events.every((e) => e.description == 'Bring notes'), isTrue);
  });
  test('converting an event to selected weekdays uses the first matching day', () async {
    final repo = CalendarRepository(db);
    final start = RepeatSchedule.day(DateTime.now());
    final next = DateTime(start.year, start.month, start.day + 1);
    final event = await repo.createEvent(title: 'Meeting', startTime: start);
    await repo.updateEvent(id: event.id, title: 'Meeting', startTime: start,
      schedule: RepeatSchedule(start: start, frequency: 'weekly', weekdays: [next.weekday], end: next));
    expect((await repo.watchManualEvents().first).single.startTime, next);
  });

  test('editing following events preserves earlier rows and updates future template', () async {
    final repo = CalendarRepository(db);
    final start = RepeatSchedule.day(DateTime.now());
    final end = DateTime(start.year, start.month, start.day + 4);
    await repo.createEvent(title: 'Original', startTime: start,
      schedule: RepeatSchedule(start: start, frequency: 'daily', end: end));
    final before = await repo.watchManualEvents().first;
    before.sort((a, b) => a.startTime.compareTo(b.startTime));
    final selected = before[2];
    await repo.updateFollowingEvents(id: selected.id, title: 'Updated',
      description: 'New notes', startTime: selected.startTime,
      schedule: RepeatSchedule(start: selected.startTime, frequency: 'daily', end: end));
    await repo.extendRecurringEvents();
    final after = await repo.watchManualEvents().first;
    expect(after.length, 5);
    expect(after.where((e) => e.title == 'Original').length, 2);
    expect(after.where((e) => e.title == 'Updated').length, 3);
    for (final old in before.take(2)) {
      final retained = after.firstWhere((e) => e.id == old.id);
      expect(retained.title, old.title);
      expect(retained.startTime, old.startTime);
      expect(retained.description, old.description);
    }
  });

  test('changing future frequency truncates the old series without duplicate regeneration', () async {
    final repo = CalendarRepository(db);
    final start = RepeatSchedule.day(DateTime.now());
    final end = DateTime(start.year, start.month, start.day + 14);
    await repo.createEvent(title: 'Daily', startTime: start,
      schedule: RepeatSchedule(start: start, frequency: 'daily', end: end));
    final before = await repo.watchManualEvents().first;
    before.sort((a, b) => a.startTime.compareTo(b.startTime));
    final selected = before[2];
    await repo.updateFollowingEvents(id: selected.id, title: 'Weekly', startTime: selected.startTime,
      schedule: RepeatSchedule(start: selected.startTime, frequency: 'weekly', end: end));
    await repo.extendRecurringEvents();
    await repo.extendRecurringEvents();
    final after = await repo.watchManualEvents().first;
    expect(after.where((e) => e.title == 'Daily').length, 2);
    expect(after.where((e) => e.title == 'Weekly').length, 2);
    expect(after.map((e) => e.startTime).toSet().length, after.length);
  });

  test('monthly title-only series edit preserves month-end anchor', () async {
    final repo = CalendarRepository(db);
    final year = DateTime.now().year;
    final start = DateTime(year, 1, 31, 9);
    final end = DateTime(year, 4, 30);
    await repo.createEvent(title: 'Original', startTime: start,
      schedule: RepeatSchedule(start: start, frequency: 'monthly', end: end));
    final before = await repo.watchManualEvents().first;
    final feb = before.firstWhere((e) => e.startTime.month == 2);
    await repo.updateFollowingEvents(id: feb.id, title: 'Updated', startTime: feb.startTime,
      schedule: RepeatSchedule(start: feb.startTime, frequency: 'monthly', end: end));
    await repo.extendRecurringEvents();
    final after = await repo.watchManualEvents().first;
    expect(after.length, 4);
    expect(after.firstWhere((e) => e.startTime.month == 3).startTime.day, 31);
    expect(after.firstWhere((e) => e.id == feb.id).title, 'Updated');
  });

  test('habit starts and unscheduled dates cannot be marked complete', () async {
    final repo = HabitsRepository(db);
    final today = RepeatSchedule.day(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final id = await repo.createHabit('Exercise', description: 'Walk',
      schedule: RepeatSchedule(start: tomorrow, frequency: 'daily'));
    await repo.setCompletedForDate(id, today, true);
    expect(await repo.watchLogsForHabit(id).first, isEmpty);
    final habit = (await repo.getHabit(id))!;
    expect(habit.description, 'Walk');
    expect(habit.scheduledOn(today), isFalse);
  });
  test('legacy JSON without new nullable fields still restores', () async {
    final repo = HabitsRepository(db);
    final id = await repo.createHabit('Legacy');
    final json = (await repo.getHabit(id))!.toJson()..remove('schedule')..remove('description');
    final restored = Habit.fromJson(json);
    expect(restored.schedule, isNull);
    expect(restored.description, isNull);
    expect(restored.scheduledOn(restored.createdAt), isTrue);
  });
}
