import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/scheduling/repeat_schedule.dart';

class TasksRepository {
  TasksRepository(this._db);
  final AppDatabase _db;

  Stream<List<Task>> watchAllTasks() =>
      (_db.select(_db.tasks)..orderBy([(t) => OrderingTerm.asc(t.dueDate)])).watch();

  Stream<List<Category>> watchCategories() =>
      (_db.select(_db.categories)..where((c) => c.kind.equals('task'))).watch();

  Future<String> createTask({
    required String title, DateTime? dueDate, String priority = 'medium',
    String? description, String? categoryId, RepeatSchedule? schedule,
    bool reminderEnabled = true, String reminderMode = 'notification',
  }) => _db.transaction(() async {
    if (schedule != null) RepeatSchedule.decode(schedule.encode());
    final id = const Uuid().v4();
    final repeating = schedule != null && schedule.frequency != 'none';
    final first = schedule == null ? dueDate : schedule.between(
      schedule.start, DateTime(schedule.start.year + 1, schedule.start.month, schedule.start.day)).firstOrNull;
    if (schedule != null && first == null) throw ArgumentError('No scheduled date in this range');
    final row = await _db.into(_db.tasks).insertReturning(TasksCompanion.insert(
      id: Value(id), title: title, dueDate: Value(first),
      description: Value(description), categoryId: Value(categoryId),
      schedule: Value(schedule?.encode()), recurrenceId: Value(repeating ? id : null),
      priority: Value(priority), reminderEnabled: Value(reminderEnabled),
      reminderMode: Value(reminderMode),
    ));
    if (repeating) await _extend(row);
    return id;
  });

  /// Completion never changes the series anchor or another occurrence.
  Future<void> setTaskDone(String id, bool done) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
        status: Value(done ? 'done' : 'open'),
        completedAt: Value(done ? DateTime.now() : null)));

  Future<void> deleteTask(String id) => _db.transaction(() async {
    await (_db.delete(_db.subtasks)..where((s) => s.taskId.equals(id))).go();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  });

  Future<void> extendRecurringTasks() => _db.transaction(() async {
    final heads = await (_db.select(_db.tasks)..where(
      (t) => t.recurrenceId.equalsExp(t.id) & t.schedule.isNotNull())).get();
    for (final head in heads) { await _extend(head); }
  });

  Future<void> _extend(Task head) async {
    final schedule = RepeatSchedule.decode(head.schedule)!;
    final from = head.recurrenceNextGenerationDate ?? head.dueDate!;
    final now = DateTime.now();
    final horizon = DateTime(now.year + 1, now.month, now.day);
    if (!from.isBefore(horizon)) return;
    final dates = schedule.between(DateTime(from.year, from.month, from.day + 1), horizon).toList();
    await _db.batch((batch) {
      for (final date in dates) {
        batch.insert(_db.tasks, TasksCompanion.insert(
          title: head.title, dueDate: Value(date), description: Value(head.description),
          categoryId: Value(head.categoryId), priority: Value(head.priority),
          recurrenceId: Value(head.id), reminderEnabled: Value(head.reminderEnabled),
          reminderMode: Value(head.reminderMode),
        ));
      }
    });
    await (_db.update(_db.tasks)..where((t) => t.id.equals(head.id))).write(
      TasksCompanion(recurrenceNextGenerationDate: Value(horizon)));
  }
}
