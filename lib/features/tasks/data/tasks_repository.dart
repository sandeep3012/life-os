import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class TasksRepository {
  TasksRepository(this._db);

  final AppDatabase _db;

  Stream<List<Task>> watchAllTasks() {
    return (_db.select(_db.tasks)
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch();
  }

  Future<String> createTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    final row = await _db.into(_db.tasks).insertReturning(
      TasksCompanion.insert(
        title: title,
        dueDate: Value(dueDate),
        priority: Value(priority),
      ),
    );
    return row.id;
  }

  Future<void> setTaskDone(String id, bool done) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(done ? 'done' : 'open'),
        completedAt: Value(done ? DateTime.now() : null),
      ),
    );
  }

  Future<void> deleteTask(String id) {
    return (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }
}
