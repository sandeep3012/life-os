import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

void main() {
  late AppDatabase db;
  late TasksRepository repo;

  // Every Monday at 7:00, from a Monday a week ago.
  final now = DateTime.now();
  final lastMonday = DateTime(now.year, now.month, now.day - now.weekday + 1 - 7, 7);
  final weekly = RepeatSchedule(
    start: lastMonday,
    frequency: 'weekly',
    weekdays: const [DateTime.monday],
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TasksRepository(db);
  });
  tearDown(() => db.close());

  Future<List<Task>> all() => (db.select(db.tasks)
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .get();

  Future<(List<Task>, Task)> seriesFromThird() async {
    await repo.createTask(title: 'Gym', schedule: weekly);
    final tasks = await all();
    // Mark the first one done: history that must not change.
    await repo.setTaskDone(tasks[0].id, true);
    return (tasks, tasks[2]);
  }

  test('editing this and future renames them and keeps earlier ones', () async {
    final (before, third) = await seriesFromThird();

    await repo.updateFollowingTasks(
      selected: third,
      title: 'Workout',
      priority: 'high',
      reminderEnabled: false,
      reminderMode: 'notification',
      schedule: weekly.copyWith(start: third.dueDate),
    );

    final after = await all();
    expect(after.length, before.length, reason: 'same days, nothing rebuilt');
    expect(after[0].title, 'Gym');
    expect(after[0].status, 'done');
    expect(after[1].title, 'Gym');
    expect(after.skip(2).every((t) => t.title == 'Workout'), isTrue);
    expect(after.skip(2).every((t) => t.priority == 'high'), isTrue);
    // Ids are kept, and the third now heads its own series.
    expect(after[2].id, third.id);
    expect(after.skip(2).every((t) => t.recurrenceId == third.id), isTrue);
    // The earlier series stops the day before.
    final head = RepeatSchedule.decode(after[0].schedule)!;
    expect(RepeatSchedule.day(head.end!), RepeatSchedule.day(third.dueDate!).subtract(const Duration(days: 1)));
  });

  test('a new time of day moves every later one', () async {
    final (_, third) = await seriesFromThird();
    final due = third.dueDate!;
    await repo.updateFollowingTasks(
      selected: third,
      title: 'Gym',
      priority: 'medium',
      reminderEnabled: false,
      reminderMode: 'notification',
      schedule: weekly.copyWith(start: DateTime(due.year, due.month, due.day, 18, 30)),
    );
    final after = await all();
    expect(after[1].dueDate!.hour, 7);
    expect(after.skip(2).every((t) => t.dueDate!.hour == 18 && t.dueDate!.minute == 30), isTrue);
  });

  test('a new pattern rebuilds the later ones from it', () async {
    final (_, third) = await seriesFromThird();
    final due = third.dueDate!;
    await repo.updateFollowingTasks(
      selected: third,
      title: 'Gym',
      priority: 'medium',
      reminderEnabled: false,
      reminderMode: 'notification',
      schedule: RepeatSchedule(
        start: due,
        frequency: 'weekly',
        weekdays: const [DateTime.monday, DateTime.thursday],
      ),
    );
    final after = await all();
    final later = after.where((t) => !t.dueDate!.isBefore(RepeatSchedule.day(due))).toList();
    expect(later.first.id, third.id, reason: 'the edited one keeps its id');
    expect(later.map((t) => t.dueDate!.weekday).toSet(), {DateTime.monday, DateTime.thursday});
    // Earlier ones are untouched.
    final earlier = after.where((t) => t.dueDate!.isBefore(RepeatSchedule.day(due)));
    expect(earlier.map((t) => t.dueDate!.weekday).toSet(), {DateTime.monday});
  });

  test('deleting this and future keeps earlier and finished ones', () async {
    final (before, third) = await seriesFromThird();
    // A later one already ticked off.
    await repo.setTaskDone(before[4].id, true);

    await repo.deleteFollowingTasks(third);

    final after = await all();
    expect(after.map((t) => t.id), [before[0].id, before[1].id, before[4].id]);
    // Nothing more is generated past the cut.
    await repo.extendRecurringTasks();
    expect(await all(), hasLength(3));
  });

  test('editing a one-off task keeps its stored schedule on the new time', () async {
    final at9 = DateTime(now.year, now.month, now.day + 2, 9);
    await repo.createTask(title: 'Dentist', schedule: RepeatSchedule(start: at9));
    final task = (await all()).single;
    final at18 = DateTime(at9.year, at9.month, at9.day, 18, 30);

    await repo.updateTask(
      id: task.id,
      title: 'Dentist',
      dueDate: at18,
      priority: 'medium',
      reminderEnabled: false,
      reminderMode: 'notification',
      schedule: RepeatSchedule(start: at18),
    );

    final updated = (await all()).single;
    expect(updated.dueDate, at18);
    // What the edit sheet reads back.
    expect(RepeatSchedule.decode(updated.schedule)!.start, at18);
  });

  test('giving a one-off task a repeat turns it into a series', () async {
    final start = DateTime(now.year, now.month, now.day + 1, 8);
    await repo.createTask(title: 'Stretch', dueDate: start);
    final task = (await all()).single;

    await repo.updateTask(
      id: task.id,
      title: 'Stretch',
      dueDate: start,
      priority: 'medium',
      reminderEnabled: false,
      reminderMode: 'notification',
      schedule: RepeatSchedule(start: start, frequency: 'daily'),
    );

    final tasks = await all();
    expect(tasks.length, greaterThan(300));
    expect(tasks.every((t) => t.recurrenceId == task.id), isTrue);
  });
}
