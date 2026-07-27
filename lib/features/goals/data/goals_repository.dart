import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Goal>> watchGoals() {
    return (_db.select(
      _db.goals,
    )..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).watch();
  }

  Stream<List<GoalLink>> watchAllLinks() => _db.select(_db.goalLinks).watch();

  Future<String> createGoal({
    required String title,
    String type = 'generic',
    double? targetValue,
    double currentValue = 0,
    DateTime? targetDate,
  }) async {
    final row = await _db.into(_db.goals).insertReturning(
      GoalsCompanion.insert(
        title: title,
        type: Value(type),
        targetValue: Value(targetValue),
        currentValue: Value(currentValue),
        targetDate: Value(targetDate),
      ),
    );
    return row.id;
  }

  Future<void> updateProgress(String goalId, double currentValue) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(currentValue: Value(currentValue)),
    );
  }

  Future<void> addLink({
    required String goalId,
    required String linkedType,
    required String linkedId,
  }) {
    return _db.into(_db.goalLinks).insert(
      GoalLinksCompanion.insert(goalId: goalId, linkedType: linkedType, linkedId: linkedId),
    );
  }

  Future<void> removeLink(String linkId) {
    return (_db.delete(_db.goalLinks)..where((l) => l.id.equals(linkId))).go();
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goalLinks)..where((l) => l.goalId.equals(id))).go();
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  }
}
