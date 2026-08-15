import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// The Calendar screen is a merged view over this table plus task due dates
/// and habit occurrences — [sourceType]/[sourceId] let a calendar entry point
/// back at the task/habit/goal that generated it (polymorphic reference,
/// deliberately not a foreign key, since it can point at three different
/// tables) instead of duplicating that data here. `sourceType == manual`
/// means the row is a standalone event with no backing record.
class Events extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();

  /// manual | task | habit | goal
  TextColumn get sourceType => text().withDefault(const Constant('manual'))();
  TextColumn get sourceId => text().nullable()();

  /// none | daily | weekly | monthly | yearly. Meaningful only on the head
  /// row of a recurring series ([recurrenceId] == [id]) — generated
  /// occurrence rows always carry 'none', since only the head drives further
  /// generation (see [CalendarRepository.extendRecurringEvents]).
  TextColumn get frequency => text().withDefault(const Constant('none'))();

  /// The series stops generating occurrences past this date. Null means
  /// generate indefinitely, capped instead by the repository's rolling
  /// 365-day horizon.
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();

  /// Groups the head row and every occurrence generated from it. Null for a
  /// plain one-off event. Not a foreign key — same polymorphic-reference
  /// idiom as [sourceType]/[sourceId] above, just self-referential.
  TextColumn get recurrenceId => text().nullable()();

  /// Head-row-only bookkeeping: the start time up to which occurrences have
  /// already been generated, so extending the horizon later doesn't rescan
  /// or duplicate existing rows.
  DateTimeColumn get recurrenceNextGenerationDate => dateTime().nullable()();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// notification | alarm — see ReminderMode.
  TextColumn get reminderMode =>
      text().withDefault(const Constant('notification'))();

  /// Minutes before [startTime] the reminder fires. 0 = at start time.
  IntColumn get reminderMinutesBefore =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
