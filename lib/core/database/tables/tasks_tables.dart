import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'categories_table.dart';

class Tasks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// high | medium | low
  TextColumn get priority => text().withDefault(const Constant('medium'))();

  /// open | done
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Subtasks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
