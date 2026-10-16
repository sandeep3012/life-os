import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// The one category list tasks and habits share. Stored as `task` because
/// that's what task categories were already called.
const plannerCategoryKind = 'task';

/// Shared taxonomy: finance categories, spend-analyzer categories, and
/// note/document/habit/goal tags all draw from one table so the AI Analyser
/// and Spend Analyzer can group across modules by a single `categoryId`.
class Categories extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('label'))();
  TextColumn get colorHex => text()();

  /// expense | income | task ([plannerCategoryKind], shared by tasks and
  /// habits). `habit` is the older, separate habit kind, folded into the
  /// shared one by `AppDatabase.mergePlannerCategories`.
  TextColumn get kind => text().withDefault(const Constant('expense'))();

  /// Where the category sits in lists and pickers — set by dragging in
  /// Settings → Categories; lower comes first.
  IntColumn get position => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Freeform tags, many-to-many via [EntityTags] so notes, documents, tasks,
/// and goals can share one tagging system instead of one per module.
class Tags extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class EntityTags extends Table {
  TextColumn get tagId => text().references(Tags, #id)();

  /// note | document | task | goal
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  @override
  Set<Column> get primaryKey => {tagId, entityType, entityId};
}
