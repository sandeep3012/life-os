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
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value('health'),
            name: 'Health',
            colorHex: '#123456',
            kind: const Value(plannerCategoryKind),
          ),
        );
    // A finance category is never deleted through here.
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value('food'),
            name: 'Food',
            colorHex: '#123456',
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: 'Keep task',
            categoryId: const Value('health'),
          ),
        );
    for (final archived in [false, true]) {
      await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              name: 'Keep habit',
              categoryId: const Value('health'),
              archived: Value(archived),
            ),
          );
    }
    await repository.delete('food');
    expect(await db.select(db.categories).get(), hasLength(2));
    await repository.delete('health');
    expect(
      (await db.select(db.categories).get()).map((c) => c.id),
      ['food'],
    );
    expect((await db.select(db.tasks).getSingle()).title, 'Keep task');
    expect((await db.select(db.tasks).getSingle()).categoryId, isNull);
    final habits = await db.select(db.habits).get();
    expect(habits, hasLength(2));
    expect(habits.every((habit) => habit.categoryId == null), isTrue);
  });

  test('habit categories fold into the list tasks share', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> category(String id, String name, String kind) => db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: Value(id),
            name: name,
            colorHex: '#123456',
            kind: Value(kind),
          ),
        );
    await category('task-health', 'Health', 'task');
    await category('habit-health', 'health', 'habit'); // same name, any case
    await category('habit-reading', 'Reading', 'habit');
    await category('food', 'Food', 'expense');
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            name: 'Walk',
            categoryId: const Value('habit-health'),
          ),
        );
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            name: 'Read',
            categoryId: const Value('habit-reading'),
          ),
        );

    await db.mergePlannerCategories();
    await db.mergePlannerCategories(); // and again: nothing more to do

    final kinds = {
      for (final c in await db.select(db.categories).get()) c.id: c.kind,
    };
    expect(kinds, {
      'task-health': 'task',
      'habit-reading': 'task',
      'food': 'expense',
    });
    final habits = {
      for (final h in await db.select(db.habits).get()) h.name: h.categoryId,
    };
    expect(habits, {'Walk': 'task-health', 'Read': 'habit-reading'});
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
