import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// DB-only access for study books and their notes.
///
/// A book's progress percentage is not stored — it's derived from how many of
/// its notes have been reviewed, the same way habit streaks are derived.
class LearnRepository {
  LearnRepository(this._db);

  final AppDatabase _db;

  Stream<List<LearnBook>> watchBooks() {
    return (_db.select(_db.learnBooks)
          ..where((b) => b.archived.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .watch();
  }

  Stream<List<LearnNote>> watchNotes() {
    return (_db.select(_db.learnNotes)
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Future<String> createBook({
    required String name,
    String colorHex = '#4B7BA6',
  }) async {
    final row = await _db.into(_db.learnBooks).insertReturning(
      LearnBooksCompanion.insert(name: name, colorHex: Value(colorHex)),
    );
    return row.id;
  }

  Future<String> createNote({
    required String bookId,
    required String title,
    String excerpt = '',
    String bodyJson = '[]',
    String prompt = '',
    String tagsCsv = '',
    int minutes = 3,
  }) async {
    final row = await _db.into(_db.learnNotes).insertReturning(
      LearnNotesCompanion.insert(
        bookId: bookId,
        title: title,
        excerpt: Value(excerpt),
        bodyJson: Value(bodyJson),
        prompt: Value(prompt),
        tagsCsv: Value(tagsCsv),
        minutes: Value(minutes),
        // New material is due immediately — the point of the review queue.
        reviewDueAt: Value(DateTime.now()),
      ),
    );
    return row.id;
  }

  Future<void> setStarred(String id, bool starred) {
    return (_db.update(_db.learnNotes)..where((n) => n.id.equals(id)))
        .write(LearnNotesCompanion(starred: Value(starred)));
  }

  /// Marks a note reviewed and schedules the next repetition.
  ///
  /// Intervals double from one day up to a 64-day ceiling, which is the
  /// standard expanding-interval schedule; [reviewLater] instead nudges it to
  /// tomorrow without advancing the streak of successful recalls.
  Future<void> markReviewed(LearnNote note) {
    final previous = note.lastReviewedAt;
    final elapsed = previous == null
        ? 1
        : DateTime.now().difference(previous).inDays.clamp(1, 64);
    final next = (elapsed * 2).clamp(1, 64);

    return (_db.update(_db.learnNotes)..where((n) => n.id.equals(note.id)))
        .write(
      LearnNotesCompanion(
        lastReviewedAt: Value(DateTime.now()),
        reviewDueAt: Value(DateTime.now().add(Duration(days: next))),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reviewLater(String id) {
    return (_db.update(_db.learnNotes)..where((n) => n.id.equals(id))).write(
      LearnNotesCompanion(
        reviewDueAt: Value(DateTime.now().add(const Duration(days: 1))),
      ),
    );
  }

  Future<void> deleteNote(String id) {
    return (_db.delete(_db.learnNotes)..where((n) => n.id.equals(id))).go();
  }
}
