import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Shared taxonomy: finance categories, spend-analyzer categories, and
/// note/document/habit/goal tags all draw from one table so the AI Analyser
/// and Spend Analyzer can group across modules by a single `categoryId`.
class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('label'))();
  TextColumn get colorHex => text()();

  /// expense | income | habit | goal | note | document
  TextColumn get kind => text().withDefault(const Constant('expense'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

/// Freeform tags, many-to-many via [EntityTags] so notes, documents, tasks,
/// and goals can share one tagging system instead of one per module.
class Tags extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class EntityTags extends Table {
  TextColumn get tagId => text().references(Tags, #id)();

  /// note | document | task | goal
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  @override
  Set<Column> get primaryKey => {tagId, entityType, entityId};
}
