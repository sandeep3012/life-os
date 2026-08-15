import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Goals extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// financial | habit | generic — drives which progress representation
  /// (₹ amount, count, or percent) the Goals screen renders for this card.
  TextColumn get type => text().withDefault(const Constant('generic'))();

  DateTimeColumn get targetDate => dateTime().nullable()();
  RealColumn get targetValue => real().nullable()();
  RealColumn get currentValue => real().withDefault(const Constant(0))();

  /// active | completed | abandoned
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Opt-in, like habits' per-item reminder — a goal doesn't imply urgency
  /// the way an unpaid bill does. Only meaningful when [targetDate] is set.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// notification | alarm — see `ReminderMode`.
  TextColumn get reminderMode =>
      text().withDefault(const Constant('notification'))();

  /// How many days before [targetDate] the reminder fires. 0 = on the
  /// deadline itself. Mirrors Bills' `reminderDaysBefore` shape, since a
  /// goal deadline is date-only like a bill's due date.
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// An ordered checklist item under a goal — purely organizational. Never
/// read by the AI Analyser's goal-pacing insight and never feeds
/// `Goals.currentValue`/`targetValue`, which stay driven exclusively by the
/// detail screen's +/- progress buttons.
class GoalMilestones extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get goalId => text().references(Goals, #id)();
  TextColumn get title => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// Set once at creation to the goal's current milestone count, so new
  /// items append at the end. No reordering UI in this pass.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic many-to-many linking a goal to whatever it tracks progress
/// against (a habit, an account, a task) — matches the "Savings" / "Morning
/// workout" / "Credit Card" chips shown under each goal card.
class GoalLinks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get goalId => text().references(Goals, #id)();

  /// habit | account | task
  TextColumn get linkedType => text()();
  TextColumn get linkedId => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {goalId, linkedType, linkedId},
  ];
}
