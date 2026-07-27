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

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
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
  List<Set<Column>> get uniqueKeys => [
    {goalId, linkedType, linkedId},
  ];
}
