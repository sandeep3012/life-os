import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/scheduling/repeat_schedule.dart';

class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

  static const _recurrenceHorizonDays = 365;

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

  Future<RepeatSchedule?> getSeriesSchedule(Event event) async {
    final head = event.recurrenceId == null ? event : await getEvent(event.recurrenceId!);
    final saved = RepeatSchedule.decode(head?.schedule ?? event.schedule);
    return saved ?? (head == null ? null : RepeatSchedule(start: head.startTime,
      frequency: head.frequency, end: head.recurrenceEndDate));
  }

  /// Split at the selected occurrence. Past rows retain their IDs and data;
  /// the old head is capped, and the replacement series owns future generation.
  Future<void> updateFollowingEvents({required String id, required String title,
    String? description, required RepeatSchedule schedule, required DateTime startTime,
    DateTime? endTime, bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification, int reminderMinutesBefore = 0,
  }) => _db.transaction(() async {
    final selected = await getEvent(id);
    if (selected == null) throw StateError('Event no longer exists');
    final seriesId = selected.recurrenceId;
    if (seriesId == null) throw StateError('Event is not part of a series');
    if (RepeatSchedule.day(startTime).isBefore(RepeatSchedule.day(selected.startTime))) {
      throw ArgumentError('The replacement series cannot start before the selected date');
    }
    RepeatSchedule.decode(schedule.encode());
    if (!schedule.hasOccurrence) throw ArgumentError('No scheduled day in this range');
    final head = await getEvent(seriesId);
    final originalRule = await getSeriesSchedule(selected);
    final following = (await getEventsInSeries(seriesId))
        .where((e) => !e.startTime.isBefore(selected.startTime)).toList();
    final originalWeekdays = originalRule == null ? <int>{} :
        (originalRule.weekdays.isEmpty ? [originalRule.start.weekday] : originalRule.weekdays).toSet();
    final newWeekdays = (schedule.weekdays.isEmpty ? [schedule.start.weekday] : schedule.weekdays).toSet();
    final sameWeekdays = schedule.frequency != 'weekly' ||
        (originalWeekdays.length == newWeekdays.length && originalWeekdays.containsAll(newWeekdays));
    final preserveDates = originalRule != null && schedule.frequency == originalRule.frequency && sameWeekdays &&
        schedule.end == originalRule.end && RepeatSchedule.day(startTime) == RepeatSchedule.day(selected.startTime);
    final cutoff = DateTime(selected.startTime.year, selected.startTime.month, selected.startTime.day - 1);
    if (head != null && head.startTime.isBefore(selected.startTime)) {
      final rule = (await getSeriesSchedule(head))!;
      final json = head.schedule == null ? <String, dynamic>{} : jsonDecode(head.schedule!) as Map<String, dynamic>;
      json.addAll(jsonDecode(rule.copyWith(end: cutoff).encode()) as Map<String, dynamic>);
      await (_db.update(_db.events)..where((e) => e.id.equals(head.id))).write(
        EventsCompanion(recurrenceEndDate: Value(cutoff), schedule: Value(jsonEncode(json))));
    }
    if (preserveDates) {
      // Title/reminder/time-only edits must not turn a Jan-31 monthly series
      // into a day-28 series when the user selects February's occurrence.
      final original = originalRule;
      final rule = original.copyWith(start: DateTime(original.start.year,
        original.start.month, original.start.day, startTime.hour, startTime.minute));
      final duration = endTime?.difference(startTime);
      final encoded = jsonEncode({...jsonDecode(rule.encode()) as Map<String, dynamic>,
        'template': {'title': title, 'description': description, 'durationMinutes': duration?.inMinutes,
          'reminderEnabled': reminderEnabled, 'reminderMode': reminderMode.storageValue,
          'reminderMinutesBefore': reminderMinutesBefore}});
      final last = following.map((e) => e.startTime).reduce((a, b) => a.isAfter(b) ? a : b);
      for (final event in following) {
        final time = DateTime(event.startTime.year, event.startTime.month,
          event.startTime.day, startTime.hour, startTime.minute);
        await (_db.update(_db.events)..where((e) => e.id.equals(event.id))).write(EventsCompanion(
          title: Value(title), description: Value(description), startTime: Value(time),
          endTime: Value(duration == null ? null : time.add(duration)),
          recurrenceId: Value(selected.id), schedule: Value(encoded),
          frequency: Value(event.id == selected.id ? rule.frequency : 'none'),
          recurrenceEndDate: Value(event.id == selected.id ? rule.end : null),
          recurrenceNextGenerationDate: Value(event.id == selected.id ? head?.recurrenceNextGenerationDate ?? last : null),
          reminderEnabled: Value(reminderEnabled), reminderMode: Value(reminderMode.storageValue),
          reminderMinutesBefore: Value(reminderMinutesBefore)));
      }
      return;
    }
    await (_db.delete(_db.events)..where((e) => e.recurrenceId.equals(seriesId) &
      e.startTime.isBiggerOrEqualValue(selected.startTime))).go();
    await createEvent(title: title, description: description, schedule: schedule,
      startTime: startTime, endTime: endTime, reminderEnabled: reminderEnabled,
      reminderMode: reminderMode, reminderMinutesBefore: reminderMinutesBefore);
  });

  /// Creates a standalone event, or the head row of a recurring series when
  /// [frequency] != 'none'. For a recurring series this also generates every
  /// occurrence up to a 365-day rolling horizon (or [recurrenceEndDate] if
  /// sooner). The rolling horizon bounds the number of generated rows.
  Future<Event> createEvent({
    required String title,
    String? description,
    RepeatSchedule? schedule,
    required DateTime startTime,
    DateTime? endTime,
    String frequency = 'none',
    DateTime? recurrenceEndDate,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) async {
    schedule ??= RepeatSchedule(start: startTime, frequency: frequency, end: recurrenceEndDate);
    RepeatSchedule.decode(schedule.encode());
    final first = schedule.between(schedule.start, DateTime(schedule.start.year + 1, schedule.start.month, schedule.start.day)).firstOrNull;
    if (first == null) throw ArgumentError('No scheduled date in this range');
    final eventDuration = endTime?.difference(startTime);
    startTime = first;
    endTime = eventDuration == null ? null : first.add(eventDuration);
    frequency = schedule.frequency;
    recurrenceEndDate = schedule.end;
    final id = const Uuid().v4();
    final isRecurring = frequency != 'none';
    return _db.transaction(() async {
    final head = await _db.into(_db.events).insertReturning(
      EventsCompanion.insert(
        id: Value(id),
        title: title,
        description: Value(description),
        schedule: Value(jsonEncode({
          ...jsonDecode(schedule!.encode()) as Map<String, dynamic>,
          'template': {'title': title, 'description': description,
            'durationMinutes': eventDuration?.inMinutes, 'reminderEnabled': reminderEnabled,
            'reminderMode': reminderMode.storageValue, 'reminderMinutesBefore': reminderMinutesBefore},
        })),
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
    });
  }

  /// Edits a single event row — title/time/reminder only. Never touches
  /// [Events.frequency]/[Events.recurrenceEndDate]/[Events.recurrenceId], so
  /// a recurring series' shape is fixed once created (an MVP boundary — see
  /// the calendar upgrade plan notes on editing scope).
  Future<void> updateEvent({
    required String id,
    required String title,
    String? description,
    RepeatSchedule? schedule,
    required DateTime startTime,
    DateTime? endTime,
    bool reminderEnabled = false,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderMinutesBefore = 0,
  }) => _db.transaction(() async {
    final old = await getEvent(id);
    if (old == null) return;
    final rule = old.recurrenceId != null ? null : schedule;
    if (rule != null) {
      RepeatSchedule.decode(rule.encode());
      final first = rule.between(rule.start, DateTime(rule.start.year + 1, rule.start.month, rule.start.day)).firstOrNull;
      if (first == null) throw ArgumentError('No scheduled date in this range');
      final duration = endTime?.difference(startTime);
      startTime = first;
      endTime = duration == null ? null : first.add(duration);
    }
    await (_db.update(_db.events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        description: Value(description),
        startTime: Value(startTime),
        endTime: Value(endTime),
        schedule: rule == null ? const Value.absent() : Value(jsonEncode({
          ...jsonDecode(rule.encode()) as Map<String, dynamic>,
          'template': {'title': title, 'description': description,
            'durationMinutes': endTime?.difference(startTime).inMinutes,
            'reminderEnabled': reminderEnabled, 'reminderMode': reminderMode.storageValue,
            'reminderMinutesBefore': reminderMinutesBefore},
        })),
        frequency: rule == null ? const Value.absent() : Value(rule.frequency),
        recurrenceEndDate: rule == null ? const Value.absent() : Value(rule.end),
        recurrenceId: rule != null && rule.frequency != 'none' ? Value(id) : const Value.absent(),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode.storageValue),
        reminderMinutesBefore: Value(reminderMinutesBefore),
      ),
    );
    if (rule != null && rule.frequency != 'none') {
      await _generateOccurrences((await getEvent(id))!, from: startTime);
    }
  });

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
  Future<void> extendRecurringEvents() => _db.transaction(() async {
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
  });

  Future<void> _generateOccurrences(Event head, {required DateTime from}) async {
    final horizonEnd = DateTime.now().add(const Duration(days: _recurrenceHorizonDays));
    final cutoff = head.recurrenceEndDate == null
        ? horizonEnd
        : (head.recurrenceEndDate!.isBefore(horizonEnd) ? head.recurrenceEndDate! : horizonEnd);
    if (!RepeatSchedule.day(from).isBefore(RepeatSchedule.day(cutoff))) return;
    final template = head.schedule == null ? null :
        (jsonDecode(head.schedule!) as Map<String, dynamic>)['template'] as Map<String, dynamic>?;
    final duration = template == null ? head.endTime?.difference(head.startTime) :
        template['durationMinutes'] == null ? null : Duration(minutes: template['durationMinutes'] as int);

    final rule = RepeatSchedule.decode(head.schedule) ??
        RepeatSchedule(start: head.startTime, frequency: head.frequency, end: head.recurrenceEndDate);
    for (final next in rule.between(DateTime(from.year, from.month, from.day + 1), cutoff)) {
      await _db.into(_db.events).insert(
        EventsCompanion.insert(
          title: template?['title'] as String? ?? head.title,
          schedule: Value(head.schedule),
          description: Value(template == null ? head.description : template['description'] as String?),
          startTime: next,
          endTime: Value(duration == null ? null : next.add(duration)),
          frequency: const Value('none'),
          recurrenceId: Value(head.recurrenceId),
          reminderEnabled: Value(template?['reminderEnabled'] as bool? ?? head.reminderEnabled),
          reminderMode: Value(template?['reminderMode'] as String? ?? head.reminderMode),
          reminderMinutesBefore: Value(template?['reminderMinutesBefore'] as int? ?? head.reminderMinutesBefore),
        ),
      );
    }

    await (_db.update(_db.events)..where((e) => e.id.equals(head.id))).write(
      EventsCompanion(recurrenceNextGenerationDate: Value(cutoff)),
    );
  }
}
