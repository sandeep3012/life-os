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

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
