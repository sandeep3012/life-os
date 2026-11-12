import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/voice_draft.dart';

/// Gives a voice option the category the person used last time for the
/// same thing — "Swiggy" was Food delivery before, so it is again —
/// whatever the AI guessed. A category they actually said out loud wins.
class CategoryMemory {
  CategoryMemory(this._db);

  final AppDatabase _db;

  static const _lookBack = 400;

  Future<List<ResolvedVoiceDraft>> apply(
    List<ResolvedVoiceDraft> options, {
    required String spoken,
    required List<Category> categories,
  }) async {
    final byId = {for (final c in categories) c.id: c};
    final said = spoken.toLowerCase();
    final result = <ResolvedVoiceDraft>[];
    for (final option in options) {
      final named = option.draft.category;
      if (named != null && said.contains(named.toLowerCase())) {
        result.add(option);
        continue;
      }
      final id = await _remembered(option);
      final remembered = id == null ? null : byId[id];
      if (remembered == null || remembered.id == option.category?.id) {
        result.add(option);
        continue;
      }
      result.add(
        option.copyWith(category: remembered, categoryFromHistory: true),
      );
    }
    return result;
  }

  Future<String?> _remembered(ResolvedVoiceDraft option) async {
    final title = option.draft.title;
    switch (option.kind) {
      case VoiceDraftKind.expense || VoiceDraftKind.income:
        final rows =
            await (_db.select(_db.transactions)
                  ..where(
                    (t) =>
                        t.categoryId.isNotNull() &
                        (option.kind == VoiceDraftKind.expense
                            ? t.amountMinor.isSmallerThanValue(0)
                            : t.amountMinor.isBiggerThanValue(0)),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                  ..limit(_lookBack))
                .get();
        return _best(rows, title, (t) => t.merchant)?.categoryId;
      case VoiceDraftKind.task:
        final rows =
            await (_db.select(_db.tasks)
                  ..where((t) => t.categoryId.isNotNull())
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                  ..limit(_lookBack))
                .get();
        return _best(rows, title, (t) => t.title)?.categoryId;
      case VoiceDraftKind.habit:
        final rows = await (_db.select(
          _db.habits,
        )..where((h) => h.categoryId.isNotNull())).get();
        return _best(rows, title, (h) => h.name)?.categoryId;
      case VoiceDraftKind.event:
        return null; // Events have no category.
    }
  }

  /// The most recent row whose name is the same thing as [title]: the same
  /// words, or one name inside the other as whole words ("Swiggy" in
  /// "Dinner from Swiggy"). [rows] are newest first.
  static T? _best<T>(List<T> rows, String title, String Function(T) name) {
    final wanted = _normal(title);
    if (wanted.isEmpty) return null;
    for (final row in rows) {
      if (_normal(name(row)) == wanted) return row;
    }
    for (final row in rows) {
      final n = _normal(name(row));
      if (n.length < 3) continue;
      if (_containsWords(wanted, n) || _containsWords(n, wanted)) return row;
    }
    return null;
  }

  static String _normal(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _containsWords(String haystack, String needle) =>
      ' $haystack '.contains(' $needle ');
}
