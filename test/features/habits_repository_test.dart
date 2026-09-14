import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';

void main() {
  late AppDatabase db;
  late HabitsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HabitsRepository(db);
  });

  tearDown(() => db.close());

  test('getHabit returns null for a missing id', () async {
    expect(await repo.getHabit('does-not-exist'), isNull);
  });

  test('updateHabit changes name/category/reminder fields', () async {
    final id = await repo.createHabit('Read');
    await repo.updateHabit(
      id: id,
      name: 'Read daily',
      reminderEnabled: true,
      reminderHour: 21,
      reminderMinute: 30,
      reminderMode: 'alarm',
    );

    final updated = await repo.getHabit(id);
    expect(updated!.name, 'Read daily');
    expect(updated.reminderEnabled, isTrue);
    expect(updated.reminderHour, 21);
    expect(updated.reminderMinute, 30);
    expect(updated.reminderMode, 'alarm');
  });

  test('archiveHabit excludes it from watchHabits', () async {
    final id = await repo.createHabit('Meditate');
    final before = await repo.watchHabits().first;
    expect(before.map((h) => h.id), contains(id));

    await repo.archiveHabit(id);

    final after = await repo.watchHabits().first;
    expect(after.map((h) => h.id), isNot(contains(id)));
    // The row itself still exists (soft delete), just excluded from the list.
    expect((await repo.getHabit(id))!.archived, isTrue);
  });

  test(
    'setCompletedForDate persists notes, and toggling without notes keeps them',
    () async {
      final id = await repo.createHabit('Journal');
      final day = DateTime.now();

      await repo.setCompletedForDate(id, day, true, notes: 'felt great');
      var logs = await repo.watchLogsForHabit(id).first;
      expect(logs.single.notes, 'felt great');

      // Toggling completion without passing `notes` must not null it out.
      await repo.setCompletedForDate(id, day, false);
      logs = await repo.watchLogsForHabit(id).first;
      expect(logs.single.completed, isFalse);
      expect(logs.single.notes, 'felt great');

      // Explicitly clearing the note (empty string) does update it.
      await repo.setCompletedForDate(id, day, true, notes: '');
      logs = await repo.watchLogsForHabit(id).first;
      expect(logs.single.notes, '');
    },
  );

  test('watchLogsForHabit scopes to one habit, newest first', () async {
    final day = DateTime.now();
    final a = await repo.createHabit(
      'Habit A',
      schedule: RepeatSchedule(
        start: day.subtract(const Duration(days: 2)),
        frequency: 'daily',
      ),
    );
    final b = await repo.createHabit(
      'Habit B',
      schedule: RepeatSchedule(
        start: day.subtract(const Duration(days: 1)),
        frequency: 'daily',
      ),
    );
    await repo.setCompletedForDate(
      a,
      day.subtract(const Duration(days: 2)),
      true,
    );
    await repo.setCompletedForDate(a, day, true);
    await repo.setCompletedForDate(
      b,
      day.subtract(const Duration(days: 1)),
      true,
    );

    final logsForA = await repo.watchLogsForHabit(a).first;
    expect(logsForA, hasLength(2));
    expect(logsForA.every((l) => l.habitId == a), isTrue);
    expect(logsForA.first.date, dateOnly(day));
    expect(logsForA.last.date, dateOnly(day.subtract(const Duration(days: 2))));
  });

  test('watchArchivedHabits returns only archived habits', () async {
    final active = await repo.createHabit('Stretch');
    final archived = await repo.createHabit('Old habit');
    await repo.archiveHabit(archived);

    final archivedList = await repo.watchArchivedHabits().first;
    expect(archivedList.map((h) => h.id), [archived]);
    expect(archivedList.map((h) => h.id), isNot(contains(active)));
  });

  test('unarchiveHabit moves a habit back into watchHabits', () async {
    final id = await repo.createHabit('Cold shower');
    await repo.archiveHabit(id);
    expect(
      (await repo.watchHabits().first).map((h) => h.id),
      isNot(contains(id)),
    );

    await repo.unarchiveHabit(id);

    final active = await repo.watchHabits().first;
    expect(active.map((h) => h.id), contains(id));
    final archived = await repo.watchArchivedHabits().first;
    expect(archived.map((h) => h.id), isNot(contains(id)));
  });

  test('createHabitCategory and watchHabitCategories filter by kind', () async {
    await repo.createHabitCategory(
      name: 'Fitness',
      icon: 'fitness_center',
      colorHex: '#2E9E63',
    );
    // A finance-kind category must not leak into the habit list.
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Groceries',
            colorHex: '#2F6FED',
            kind: const Value('expense'),
          ),
        );

    final habitCategories = await repo.watchHabitCategories().first;
    expect(habitCategories, hasLength(1));
    expect(habitCategories.single.name, 'Fitness');
    expect(habitCategories.single.kind, 'habit');
  });
}
