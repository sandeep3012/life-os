import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

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

  Future<void> createEvent({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
  }) {
    return _db.into(_db.events).insert(
      EventsCompanion.insert(title: title, startTime: startTime, endTime: Value(endTime)),
    );
  }

  Future<void> deleteEvent(String id) {
    return (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();
  }
}
