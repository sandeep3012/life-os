import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Category deletion only detaches the category; never deletes planner items.
class PlannerCategoriesRepository {
  PlannerCategoriesRepository(this.db);
  final AppDatabase db;

  /// Tasks and habits share these categories, so both let go of it.
  Future<void> delete(String id) => db.transaction(() async {
    final category = await (db.select(db.categories)..where(
          (c) => c.id.equals(id) & c.kind.equals(plannerCategoryKind),
        ))
        .getSingleOrNull();
    if (category == null) return;
    await (db.update(db.tasks)..where((t) => t.categoryId.equals(id))).write(
      const TasksCompanion(categoryId: Value(null)),
    );
    await (db.update(db.habits)..where((h) => h.categoryId.equals(id))).write(
      const HabitsCompanion(categoryId: Value(null)),
    );
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  });
}
