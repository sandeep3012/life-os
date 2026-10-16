import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/deleted_rows.dart';
import '../../../core/scheduling/repeat_schedule.dart';

class TasksRepository {
  TasksRepository(this._db);
  final AppDatabase _db;

  /// Filter in SQLite so the Planner does not load the entire task history.
  /// Null selects undated tasks; the upper bound is exclusive and DST-safe.
  Stream<List<Task>> watchTasksForDay(DateTime? day) {
    if (day != null) {
      return watchTasksInRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day + 1),
      );
    }
    final query = _db.select(_db.tasks);
    query.where((t) => t.dueDate.isNull());
    query.orderBy([
      (t) => OrderingTerm.asc(t.dueDate),
      (t) => OrderingTerm.asc(t.title),
      (t) => OrderingTerm.asc(t.id),
    ]);
    return query.watch();
  }

  Stream<List<Task>> watchTasksInRange(DateTime start, DateTime end) =>
      (_db.select(_db.tasks)
            ..where(
              (t) =>
                  t.dueDate.isBiggerOrEqualValue(start) &
                  t.dueDate.isSmallerThanValue(end),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.dueDate),
              (t) => OrderingTerm.asc(t.title),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Stream<List<Task>> watchAllTasks() => (_db.select(
    _db.tasks,
  )..orderBy([(t) => OrderingTerm.asc(t.dueDate)])).watch();

  Stream<List<Category>> watchCategories() =>
      (_db.select(
        _db.categories,
      )..where((c) => c.kind.equals(plannerCategoryKind))).watch();

  Future<String> createTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
    String? description,
    String? categoryId,
    RepeatSchedule? schedule,
    bool reminderEnabled = true,
    String reminderMode = 'notification',
  }) => _db.transaction(() async {
    if (schedule != null) RepeatSchedule.decode(schedule.encode());
    final id = const Uuid().v4();
    final repeating = schedule != null && schedule.frequency != 'none';
    final first = schedule == null
        ? dueDate
        : schedule
              .between(
                schedule.start,
                DateTime(
                  schedule.start.year + 1,
                  schedule.start.month,
                  schedule.start.day,
                ),
              )
              .firstOrNull;
    if (schedule != null && first == null) {
      throw ArgumentError('No scheduled date in this range');
    }
    final row = await _db
        .into(_db.tasks)
        .insertReturning(
          TasksCompanion.insert(
            id: Value(id),
            title: title,
            dueDate: Value(first),
            description: Value(description),
            categoryId: Value(categoryId),
            schedule: Value(schedule?.encode()),
            recurrenceId: Value(repeating ? id : null),
            priority: Value(priority),
            reminderEnabled: Value(reminderEnabled),
            reminderMode: Value(reminderMode),
          ),
        );
    if (repeating) await _extend(row);
    return id;
  });

  /// Completion never changes the series anchor or another occurrence.
  Future<void> setTaskDone(String id, bool done) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          status: Value(done ? 'done' : 'open'),
          completedAt: Value(done ? DateTime.now() : null),
        ),
      );

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    String? categoryId,
    required DateTime? dueDate,
    required String priority,
    required bool reminderEnabled,
    required String reminderMode,
    RepeatSchedule? schedule,
  }) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    final inSeries = existing.recurrenceId != null;
    final repeating = schedule != null && schedule.frequency != 'none';
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(title),
        description: Value(description),
        categoryId: Value(categoryId),
        dueDate: Value(dueDate),
        priority: Value(priority),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode),
        // A one-off task keeps its stored schedule in step with its due
        // date — it went stale before, so editing showed the old time — and
        // becomes the head of a new series if it was given a repeat. One
        // occurrence of a series leaves the series' pattern alone.
        schedule: inSeries
            ? const Value.absent()
            : Value(
                dueDate == null
                    ? null
                    : (schedule ?? RepeatSchedule(start: dueDate))
                          .copyWith(start: dueDate)
                          .encode(),
              ),
        recurrenceId: !inSeries && repeating && dueDate != null
            ? Value(id)
            : const Value.absent(),
      ),
    );
    if (!inSeries && repeating && dueDate != null) {
      final updated = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(id))).getSingle();
      await _extend(updated);
    }
  });

  /// "This and future tasks" for a repeating task: [selected] and every
  /// later occurrence take the new details and repeat pattern, and earlier
  /// ones keep the old — the series is split at [selected], which becomes
  /// the head of its own.
  ///
  /// When only the details or the time of day change, the later
  /// occurrences are rewritten in place, keeping their ids, subtasks and
  /// ticks. When the repeat pattern changes, the open ones are rebuilt from
  /// it; [selected] keeps its id either way, so whatever has it open still
  /// finds it.
  Future<void> updateFollowingTasks({
    required Task selected,
    required String title,
    String? description,
    String? categoryId,
    required String priority,
    required bool reminderEnabled,
    required String reminderMode,
    required RepeatSchedule schedule,
  }) => _db.transaction(() async {
    final seriesId = selected.recurrenceId;
    final selectedDue = selected.dueDate;
    if (seriesId == null || selectedDue == null) {
      throw ArgumentError('Not part of a repeating series');
    }
    final head = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(seriesId))).getSingleOrNull();
    final oldSchedule = RepeatSchedule.decode(head?.schedule);
    final from = RepeatSchedule.day(selectedDue);
    final following =
        await (_db.select(_db.tasks)
              ..where(
                (t) =>
                    t.recurrenceId.equals(seriesId) &
                    t.dueDate.isBiggerOrEqualValue(from),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
            .get();

    // The earlier part of the series stops the day before.
    if (head != null && head.id != selected.id && oldSchedule != null) {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(head.id))).write(
        TasksCompanion(
          schedule: Value(
            oldSchedule
                .copyWith(end: DateTime(from.year, from.month, from.day - 1))
                .encode(),
          ),
        ),
      );
    }

    final details = TasksCompanion(
      title: Value(title),
      description: Value(description),
      categoryId: Value(categoryId),
      priority: Value(priority),
      reminderEnabled: Value(reminderEnabled),
      reminderMode: Value(reminderMode),
    );

    if (oldSchedule != null && _sameDays(oldSchedule, schedule, from)) {
      for (final row in following) {
        final due = row.dueDate!;
        await (_db.update(_db.tasks)..where((t) => t.id.equals(row.id))).write(
          details.copyWith(
            dueDate: Value(
              DateTime(
                due.year,
                due.month,
                due.day,
                schedule.start.hour,
                schedule.start.minute,
              ),
            ),
            recurrenceId: Value(selected.id),
            schedule: Value(row.id == selected.id ? schedule.encode() : null),
            recurrenceNextGenerationDate: row.id == selected.id
                ? Value(
                    head?.recurrenceNextGenerationDate ?? following.last.dueDate,
                  )
                : const Value.absent(),
          ),
        );
      }
      return;
    }

    // A new pattern: clear the open later occurrences and generate afresh.
    for (final row in following) {
      if (row.id == selected.id || row.status == 'done') continue;
      await (_db.delete(
        _db.subtasks,
      )..where((s) => s.taskId.equals(row.id))).go();
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(row.id))).go();
    }
    final repeating = schedule.frequency != 'none';
    final first = schedule
        .between(
          schedule.start,
          DateTime(
            schedule.start.year + 1,
            schedule.start.month,
            schedule.start.day,
          ),
        )
        .firstOrNull;
    if (first == null) throw ArgumentError('No scheduled date in this range');
    await (_db.update(_db.tasks)..where((t) => t.id.equals(selected.id))).write(
      details.copyWith(
        dueDate: Value(first),
        schedule: Value(repeating ? schedule.encode() : null),
        recurrenceId: Value(repeating ? selected.id : null),
        recurrenceNextGenerationDate: const Value(null),
      ),
    );
    if (repeating) {
      final updated = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(selected.id))).getSingle();
      await _extend(updated);
    }
  });

  /// Whether [next] lands on the same days as [old] from [from] on — so the
  /// later occurrences can be edited in place rather than rebuilt.
  static bool _sameDays(RepeatSchedule old, RepeatSchedule next, DateTime from) {
    List<int> days(RepeatSchedule s) => [...s.weekdays]..sort();
    DateTime? endDay(RepeatSchedule s) =>
        s.end == null ? null : RepeatSchedule.day(s.end!);
    return old.frequency == next.frequency &&
        days(old).join(',') == days(next).join(',') &&
        endDay(old) == endDay(next) &&
        RepeatSchedule.day(next.start) == from;
  }

  /// "This and future tasks" for a delete: [selected] and the open
  /// occurrences after it go; earlier ones, and any already ticked off, stay.
  ///
  /// Returns what it removed (and the series' first task as it was), for
  /// Undo.
  Future<DeletedRows> deleteFollowingTasks(Task selected) =>
      _db.transaction(() async {
    final seriesId = selected.recurrenceId;
    final selectedDue = selected.dueDate;
    if (seriesId == null || selectedDue == null) {
      return deleteTask(selected.id);
    }
    final removed = DeletedRows();
    final from = RepeatSchedule.day(selectedDue);
    final head = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(seriesId))).getSingleOrNull();
    final oldSchedule = RepeatSchedule.decode(head?.schedule);
    if (head != null && head.id != selected.id && oldSchedule != null) {
      removed.add(_db.tasks, head);
      await (_db.update(_db.tasks)..where((t) => t.id.equals(head.id))).write(
        TasksCompanion(
          schedule: Value(
            oldSchedule
                .copyWith(end: DateTime(from.year, from.month, from.day - 1))
                .encode(),
          ),
        ),
      );
    }
    final following =
        await (_db.select(_db.tasks)..where(
              (t) =>
                  t.recurrenceId.equals(seriesId) &
                  t.dueDate.isBiggerOrEqualValue(from),
            ))
            .get();
    for (final row in following) {
      if (row.status == 'done' && row.id != selected.id) continue;
      removed.addAll(_db.tasks, [row]);
      removed.addAll(
        _db.subtasks,
        await (_db.select(
          _db.subtasks,
        )..where((s) => s.taskId.equals(row.id))).get(),
      );
      await (_db.delete(
        _db.subtasks,
      )..where((s) => s.taskId.equals(row.id))).go();
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(row.id))).go();
    }
    return removed;
  });

  /// Puts back what a delete removed.
  Future<void> restore(DeletedRows removed) => removed.restore(_db);

  /// Returns the task and its subtasks as they were, for Undo.
  Future<DeletedRows> deleteTask(String id) => _db.transaction(() async {
    final removed = DeletedRows()
      ..addAll(
        _db.tasks,
        await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).get(),
      )
      ..addAll(
        _db.subtasks,
        await (_db.select(
          _db.subtasks,
        )..where((s) => s.taskId.equals(id))).get(),
      );
    await (_db.delete(_db.subtasks)..where((s) => s.taskId.equals(id))).go();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    return removed;
  });

  Future<void> extendRecurringTasks() => _db.transaction(() async {
    final heads =
        await (_db.select(_db.tasks)..where(
              (t) => t.recurrenceId.equalsExp(t.id) & t.schedule.isNotNull(),
            ))
            .get();
    for (final head in heads) {
      await _extend(head);
    }
  });

  Future<void> _extend(Task head) async {
    final schedule = RepeatSchedule.decode(head.schedule)!;
    final from = head.recurrenceNextGenerationDate ?? head.dueDate!;
    final now = DateTime.now();
    final horizon = DateTime(now.year + 1, now.month, now.day);
    if (!from.isBefore(horizon)) return;
    final dates = schedule
        .between(DateTime(from.year, from.month, from.day + 1), horizon)
        .toList();
    await _db.batch((batch) {
      for (final date in dates) {
        batch.insert(
          _db.tasks,
          TasksCompanion.insert(
            title: head.title,
            dueDate: Value(date),
            description: Value(head.description),
            categoryId: Value(head.categoryId),
            priority: Value(head.priority),
            recurrenceId: Value(head.id),
            reminderEnabled: Value(head.reminderEnabled),
            reminderMode: Value(head.reminderMode),
          ),
        );
      }
    });
    await (_db.update(_db.tasks)..where((t) => t.id.equals(head.id))).write(
      TasksCompanion(recurrenceNextGenerationDate: Value(horizon)),
    );
  }
}
