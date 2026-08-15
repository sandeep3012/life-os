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
  /// already hidden), drafts with no existing row (dismissed or not) are
  /// inserted, and a still-live condition whose row already exists gets its
  /// title/severity refreshed in place — otherwise e.g. a goal's "9 days"
  /// insight would never update to "3 days" after editing the deadline,
  /// since the dedupe key (type:goalId) doesn't change. A still-true
  /// condition that was already dismissed stays dismissed (and unrefreshed)
  /// instead of reappearing every refresh.
  Future<void> reconcile(List<InsightDraft> drafts) async {
    final existing = await _db.select(_db.insights).get();
    final existingByKey = {for (final e in existing) '${e.type}:${e.relatedEntityId ?? ''}': e};
    final draftKeys = drafts.map((d) => d.dedupeKey).toSet();

    await _db.batch((batch) {
      for (final e in existing) {
        final key = '${e.type}:${e.relatedEntityId ?? ''}';
        if (!e.dismissed && !draftKeys.contains(key)) {
          batch.deleteWhere(_db.insights, (i) => i.id.equals(e.id));
        }
      }
      for (final d in drafts) {
        final match = existingByKey[d.dedupeKey];
        if (match == null) {
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
        } else if (!match.dismissed &&
            (match.title != d.title || match.severity != d.severity)) {
          batch.update(
            _db.insights,
            InsightsCompanion(severity: Value(d.severity), title: Value(d.title)),
            where: (i) => i.id.equals(match.id),
          );
        }
      }
    });
  }
}
