import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Category deletion only detaches the category; never deletes planner items.
class PlannerCategoriesRepository {
  PlannerCategoriesRepository(this.db);
  final AppDatabase db;

  Future<void> delete(String id, String kind) => db.transaction(() async {
    if (kind != 'task' && kind != 'habit') {
      throw ArgumentError.value(kind, 'kind');
    }
    final category = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id) & c.kind.equals(kind))).getSingleOrNull();
    if (category == null) return;
    if (kind == 'task') {
      await (db.update(db.tasks)..where((t) => t.categoryId.equals(id))).write(
        const TasksCompanion(categoryId: Value(null)),
      );
    } else {
      await (db.update(db.habits)..where((h) => h.categoryId.equals(id))).write(
        const HabitsCompanion(categoryId: Value(null)),
      );
    }
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  });
}
