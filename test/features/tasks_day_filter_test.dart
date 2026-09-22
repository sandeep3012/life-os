import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:life_manager/features/tasks/domain/task_date_window.dart';

void main() {
  test(
    'rolling weeks and calendar months use exclusive local date boundaries',
    () {
      final day = DateTime(2026, 12, 29, 18);
      expect(taskDateWindow(day, TaskPeriod.day), (
        start: DateTime(2026, 12, 29),
        end: DateTime(2026, 12, 30),
      ));
      expect(taskDateWindow(day, TaskPeriod.week), (
        start: DateTime(2026, 12, 29),
        end: DateTime(2027, 1, 5),
      ));
      expect(taskDateWindow(day, TaskPeriod.month), (
        start: DateTime(2026, 12),
        end: DateTime(2027, 1),
      ));
      expect(taskDateWindow(DateTime(2028, 2, 29), TaskPeriod.month), (
        start: DateTime(2028, 2),
        end: DateTime(2028, 3),
      ));
      expect(
        taskStripWindow(day, TaskPeriod.week),
        taskDateWindow(day, TaskPeriod.week),
      );
    },
  );

  test(
    'range query returns only the requested week or month, including completed tasks',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TasksRepository(db);
      final dates = [
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 28, 23, 59),
        DateTime(2026, 12, 29),
        DateTime(2027, 1, 4, 23, 59),
        DateTime(2027, 1, 5),
      ];
      for (var i = 0; i < dates.length; i++) {
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: 'Task $i',
                dueDate: Value(dates[i]),
                status: Value(i == 3 ? 'done' : 'open'),
              ),
            );
      }
      await db.into(db.tasks).insert(TasksCompanion.insert(title: 'Undated'));
      final week = taskDateWindow(DateTime(2026, 12, 29), TaskPeriod.week);
      final month = taskDateWindow(DateTime(2026, 12, 29), TaskPeriod.month);
      expect(
        (await repository.watchTasksInRange(week.start, week.end).first).map(
          (task) => task.title,
        ),
        ['Task 2', 'Task 3'],
      );
      expect(
        (await repository.watchTasksInRange(month.start, month.end).first).map(
          (task) => task.title,
        ),
        ['Task 0', 'Task 1', 'Task 2'],
      );
    },
  );

  test(
    'selected day includes midnight and completed tasks, excludes adjacent days and undated tasks',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TasksRepository(db);
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Previous day',
              dueDate: Value(DateTime(2026, 9, 19, 23, 59, 59)),
            ),
          );
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Midnight',
              dueDate: Value(DateTime(2026, 9, 20)),
            ),
          );
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Completed',
              status: const Value('done'),
              dueDate: Value(DateTime(2026, 9, 20, 23, 59, 59)),
            ),
          );
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Next day',
              dueDate: Value(DateTime(2026, 9, 21)),
            ),
          );
      await db.into(db.tasks).insert(TasksCompanion.insert(title: 'No date'));

      final selected = await repository
          .watchTasksForDay(DateTime(2026, 9, 20, 15))
          .first;
      expect(selected.map((task) => task.title), ['Midnight', 'Completed']);
      final undated = await repository.watchTasksForDay(null).first;
      expect(undated.map((task) => task.title), ['No date']);
      final empty = await repository
          .watchTasksForDay(DateTime(2026, 9, 22))
          .first;
      expect(empty, isEmpty);
    },
  );
}
