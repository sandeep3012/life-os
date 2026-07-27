import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/insight_draft.dart';

class InsightsRepository {
  InsightsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Insight>> watchActiveInsights() {
    return (_db.select(_db.insights)
          ..where((i) => i.dismissed.equals(false))
          ..orderBy([(i) => OrderingTerm.desc(i.generatedAt)]))
        .watch();
  }

  Future<void> dismiss(String id) {
    return (_db.update(_db.insights)..where((i) => i.id.equals(id))).write(
      const InsightsCompanion(dismissed: Value(true)),
    );
  }

  /// Reconciles the freshly computed [drafts] against what's persisted:
  /// insights whose underlying condition no longer holds are removed
  /// (unless the user already dismissed them — no point deleting what's
  /// already hidden), and drafts with no existing row (dismissed or not)
  /// are inserted. A still-true condition that was already dismissed stays
  /// dismissed instead of reappearing every refresh.
  Future<void> reconcile(List<InsightDraft> drafts) async {
    final existing = await _db.select(_db.insights).get();
    final existingKeys = {for (final e in existing) '${e.type}:${e.relatedEntityId ?? ''}'};
    final draftKeys = drafts.map((d) => d.dedupeKey).toSet();

    await _db.batch((batch) {
      for (final e in existing) {
        final key = '${e.type}:${e.relatedEntityId ?? ''}';
        if (!e.dismissed && !draftKeys.contains(key)) {
          batch.deleteWhere(_db.insights, (i) => i.id.equals(e.id));
        }
      }
      for (final d in drafts) {
        if (!existingKeys.contains(d.dedupeKey)) {
          batch.insert(
            _db.insights,
            InsightsCompanion.insert(
              type: d.type,
              severity: d.severity,
              title: d.title,
              relatedModule: Value(d.relatedModule),
              relatedEntityId: Value(d.relatedEntityId),
            ),
          );
        }
      }
    });
  }
}
