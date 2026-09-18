import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// A medication or supplement on the user's schedule.
///
/// Whether a dose was taken is *not* stored here — it's derived from
/// [MedicationLogs] per day, the same pattern habits use for completion, so the
/// "doses today" figure can never drift from the logged history.
class Medications extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();

  /// Free text under the name — "1 tablet · with breakfast".
  TextColumn get dosageNote => text().withDefault(const Constant(''))();

  /// Which of the day's groups this dose belongs to: `am` | `pm` | `night`.
  TextColumn get slot => text().withDefault(const Constant('am'))();

  /// Category-style colour for the pill well, stored as `#RRGGBB`.
  TextColumn get colorHex => text().withDefault(const Constant('#4B7BA6'))();

  /// Remaining doses in hand, so the screen can warn before a refill is due.
  /// Nullable — not everything is counted.
  IntColumn get stockLeft => integer().nullable()();

  /// daily | weekly | alt (alternate days)
  TextColumn get frequency => text().withDefault(const Constant('daily'))();

  /// Weekdays this applies on, as a comma-separated list of `DateTime.weekday`
  /// values (1 = Monday .. 7 = Sunday). Only meaningful for `weekly`/`alt`.
  TextColumn get daysCsv => text().withDefault(const Constant('1,2,3,4,5,6,7'))();

  /// Dose times as comma-separated 24h `HH:mm`, e.g. `08:00,22:30`.
  TextColumn get timesCsv => text().withDefault(const Constant('08:00'))();

  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per medication per day it was taken.
class MedicationLogs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get medicationId => text().references(Medications, #id)();

  /// Date-only (midnight) — one log per medication per day.
  DateTimeColumn get date => dateTime()();
  BoolColumn get taken => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {medicationId, date},
  ];
}

/// A named training day in the weekly plan — "Push Day", "Chest & Triceps".
///
/// The dashboard's "now" hero reads the block whose time window contains the
/// current time, which is why start/end are stored as minutes-from-midnight
/// rather than as a `DateTime`: the plan repeats weekly and has no date.
class WorkoutDays extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  /// `DateTime.weekday` (1 = Monday .. 7 = Sunday).
  IntColumn get weekday => integer()();

  /// Comp: the uppercase kicker above the title — "Push Day".
  TextColumn get label => text()();

  /// Comp: the serif title — "Chest & Triceps".
  TextColumn get focus => text().withDefault(const Constant(''))();

  /// Minutes from midnight, so a 7:00–8:00 AM block is 420 → 480.
  IntColumn get startMinute => integer().withDefault(const Constant(420))();
  IntColumn get endMinute => integer().withDefault(const Constant(480))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// An exercise within a [WorkoutDays] block, in display order.
class Exercises extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get workoutDayId => text().references(WorkoutDays, #id)();
  TextColumn get name => text()();

  /// Comp: "4×10" — kept as text because the plan is prose, not arithmetic.
  TextColumn get scheme => text().withDefault(const Constant(''))();

  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One logged set: what was actually lifted, on a given day.
///
/// Separate from [WorkoutLogs] because completion and performance are different
/// questions — an exercise can be ticked off without logging numbers, and a set
/// can be logged mid-session before the exercise is finished. Volume, top weight
/// and set count are all derived from these rows rather than stored.
class ExerciseSetLogs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get exerciseId => text().references(Exercises, #id)();

  /// Date-only (midnight) — sets are grouped by the day they were performed.
  DateTimeColumn get date => dateTime()();

  /// 1-based position within that day, so sets read in the order they were done.
  IntColumn get setNumber => integer()();

  IntColumn get reps => integer().withDefault(const Constant(0))();

  /// Stored in **grams**, not kilograms, for the same reason money is stored in
  /// paise: 2.5 kg plate increments are exact as integers and drift as doubles.
  /// The UI divides by 1000 for display.
  IntColumn get weightGrams => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, date, setNumber},
  ];
}

/// One row per exercise completed on a given date, so the hero's
/// "exercise 2 of 6 · 32% complete" is derived rather than stored.
class WorkoutLogs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, date},
  ];
}
