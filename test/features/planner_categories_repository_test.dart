import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/tasks/data/planner_categories_repository.dart';
import 'package:life_manager/features/tasks/domain/task_date_window.dart';

void main() {
  test('category deletion keeps tasks and active/archived habits', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = PlannerCategoriesRepository(db);
    for (final kind in ['task', 'habit']) {
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: Value(kind),
              name: kind,
              colorHex: '#123456',
              kind: Value(kind),
            ),
          );
    }
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: 'Keep task',
            categoryId: const Value('task'),
          ),
        );
    for (final archived in [false, true]) {
      await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              name: 'Keep habit',
              categoryId: const Value('habit'),
              archived: Value(archived),
            ),
          );
    }
    await repository.delete('task', 'habit');
    expect((await db.select(db.tasks).getSingle()).categoryId, 'task');
    await repository.delete('task', 'task');
    await repository.delete('habit', 'habit');
    expect(await db.select(db.categories).get(), isEmpty);
    expect((await db.select(db.tasks).getSingle()).title, 'Keep task');
    expect((await db.select(db.tasks).getSingle()).categoryId, isNull);
    final habits = await db.select(db.habits).get();
    expect(habits, hasLength(2));
    expect(habits.every((habit) => habit.categoryId == null), isTrue);
  });

  test(
    'task sections use due dates and keep completed tasks in their date group',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final today = DateTime(2026, 9, 19);
      for (final entry in [
        ('Overdue', today.subtract(const Duration(days: 1))),
        ('Today', today),
        ('Upcoming', today.add(const Duration(days: 1))),
        ('No date', null),
        ('Completed', today),
      ]) {
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: entry.$1,
                dueDate: Value(entry.$2),
                status: Value(entry.$1 == 'Completed' ? 'done' : 'open'),
              ),
            );
      }
      final groups = groupTasksByDueDate(await db.select(db.tasks).get());
      expect(groups.keys, [
        DateTime(2026, 9, 18),
        today,
        DateTime(2026, 9, 20),
      ]);
      expect(groups[today]!.map((task) => task.title), ['Completed', 'Today']);
      expect(groups.values.expand((tasks) => tasks).length, 4);
      expect(
        groups.values
            .expand((tasks) => tasks)
            .map((task) => task.id)
            .toSet()
            .length,
        4,
      );
    },
  );
}
