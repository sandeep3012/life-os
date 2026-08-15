import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/utils/date_utils.dart';

class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

  static const _recurrenceHorizonDays = 365;
  static const _maxGeneratedOccurrences = 200;

  Stream<List<Task>> watchTasksWithDueDate() {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.dueDate.isNotNull())).watch();
  }

  Stream<List<Habit>> watchHabits() => _db.select(_db.habits).watch();

  Stream<List<HabitLog>> watchCompletedHabitLogs() {
    return (_db.select(
      _db.habitLogs,
    )..where((l) => l.completed.equals(true))).watch();
  }

  /// Only standalone entries — task/habit-derived items are read from their
  /// own tables instead, so this never includes rows written on their behalf.
  Stream<List<Event>> watchManualEvents() {
    return (_db.select(
      _db.events,
    )..where((e) => e.sourceType.equals('manual'))).watch();
  }

  /// Cross-module: the Calendar screen surfaces due bills alongside tasks
  /// and habits (see the module-level doc on `Events`) without duplicating
  /// their data into that table.
  Stream<List<Bill>> watchUnpaidBills() {
    return (_db.select(_db.bills)..where((b) => b.active.equals(true))).watch();
  }

  Future<Event?> getEvent(String id) {
    return (_db.select(_db.events)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Creates a standalone event, or the head row of a recurring series when
  /// [frequency] != 'none'. For a recurring series this also generates every
  /// occurrence up to a 365-day rolling horizon (or [recurrenceEndDate] if
  /// sooner), capped at [_maxGeneratedOccurrences] rows so a missing end
  /// date can't runaway-insert.
  Future<Event> createEvent({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    String frequency = 'none',
    DateTime? recurrenceEndDate,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) async {
    final id = const Uuid().v4();
    final isRecurring = frequency != 'none';
    final head = await _db.into(_db.events).insertReturning(
      EventsCompanion.insert(
        id: Value(id),
        title: title,
        startTime: startTime,
        endTime: Value(endTime),
        frequency: Value(frequency),
        recurrenceEndDate: Value(recurrenceEndDate),
        recurrenceId: Value(isRecurring ? id : null),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode.storageValue),
        reminderMinutesBefore: Value(reminderMinutesBefore),
      ),
    );
    if (isRecurring) {
      await _generateOccurrences(head, from: head.startTime);
    }
    return head;
  }

  /// Edits a single event row — title/time/reminder only. Never touches
  /// [Events.frequency]/[Events.recurrenceEndDate]/[Events.recurrenceId], so
  /// a recurring series' shape is fixed once created (an MVP boundary — see
  /// the calendar upgrade plan notes on editing scope).
  Future<void> updateEvent({
    required String id,
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) {
    return (_db.update(_db.events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        startTime: Value(startTime),
        endTime: Value(endTime),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode.storageValue),
        reminderMinutesBefore: Value(reminderMinutesBefore),
      ),
    );
  }

  /// Deletes a single event row. Deleting a recurring series' head row just
  /// stops future top-up generation for that series (its `recurrenceId ==
  /// id` head lookup in [extendRecurringEvents] no longer matches);
  /// already-generated future occurrences are unaffected and remain as
  /// ordinary events. Use [deleteEventSeries] to remove a whole series.
  Future<void> deleteEvent(String id) {
    return (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();
  }

  /// Every event sharing [recurrenceId] — the head row plus every generated
  /// occurrence. Used to look up which ids need their reminders cancelled
  /// before [deleteEventSeries] bulk-deletes the rows.
  Future<List<Event>> getEventsInSeries(String recurrenceId) {
    return (_db.select(
      _db.events,
    )..where((e) => e.recurrenceId.equals(recurrenceId))).get();
  }

  /// Deletes every event sharing [recurrenceId] — the head row and every
  /// generated occurrence — in one query.
  Future<void> deleteEventSeries(String recurrenceId) {
    return (_db.delete(
      _db.events,
    )..where((e) => e.recurrenceId.equals(recurrenceId))).go();
  }

  /// App-start top-up: for every still-active recurring series (a head row
  /// where `recurrenceId == id` and `frequency != 'none'`), generates any
  /// occurrences needed to keep the rolling 365-day horizon full. Mirrors
  /// `FinanceRepository.generateDueRecurringTransactions`'s role as the
  /// catch-up call fired from `app.dart`, but extends the horizon forward
  /// rather than backfilling missed past dates — a recurring event with no
  /// user present to see it just isn't generated for the past.
  Future<void> extendRecurringEvents() async {
    final heads = await (_db.select(_db.events)..where(
      (e) => e.recurrenceId.equalsExp(e.id) & e.frequency.equals('none').not(),
    )).get();

    final horizonEnd = DateTime.now().add(const Duration(days: _recurrenceHorizonDays));
    for (final head in heads) {
      final generatedUpTo = head.recurrenceNextGenerationDate ?? head.startTime;
      if (!generatedUpTo.isBefore(horizonEnd)) continue;
      if (head.recurrenceEndDate != null && !generatedUpTo.isBefore(head.recurrenceEndDate!)) {
        continue;
      }
      await _generateOccurrences(head, from: generatedUpTo);
    }
  }

  Future<void> _generateOccurrences(Event head, {required DateTime from}) async {
    final horizonEnd = DateTime.now().add(const Duration(days: _recurrenceHorizonDays));
    final cutoff = head.recurrenceEndDate == null
        ? horizonEnd
        : (head.recurrenceEndDate!.isBefore(horizonEnd) ? head.recurrenceEndDate! : horizonEnd);
    final duration = head.endTime?.difference(head.startTime);

    var next = addRecurrenceInterval(from, head.frequency);
    var iterations = 0;
    var last = from;
    while (!next.isAfter(cutoff) && iterations < _maxGeneratedOccurrences) {
      await _db.into(_db.events).insert(
        EventsCompanion.insert(
          title: head.title,
          startTime: next,
          endTime: Value(duration == null ? null : next.add(duration)),
          frequency: const Value('none'),
          recurrenceId: Value(head.recurrenceId),
          reminderEnabled: Value(head.reminderEnabled),
          reminderMode: Value(head.reminderMode),
          reminderMinutesBefore: Value(head.reminderMinutesBefore),
        ),
      );
      last = next;
      next = addRecurrenceInterval(next, head.frequency);
      iterations++;
    }

    await (_db.update(_db.events)..where((e) => e.id.equals(head.id))).write(
      EventsCompanion(recurrenceNextGenerationDate: Value(last)),
    );
  }
}
