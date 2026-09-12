import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/learn_repository.dart';

final learnRepositoryProvider = Provider<LearnRepository>((ref) {
  return LearnRepository(ref.watch(appDatabaseProvider));
});

final learnBooksProvider = StreamProvider<List<LearnBook>>((ref) {
  return ref.watch(learnRepositoryProvider).watchBooks();
});

final learnNotesProvider = StreamProvider<List<LearnNote>>((ref) {
  return ref.watch(learnRepositoryProvider).watchNotes();
});

final learnNoteByIdProvider = Provider.family<LearnNote?, String>((ref, id) {
  final notes = ref.watch(learnNotesProvider).value ?? const [];
  final match = notes.where((n) => n.id == id);
  return match.isEmpty ? null : match.first;
});

/// Notes whose review date has arrived — the comp's "review queue" count.
final dueNotesProvider = Provider<List<LearnNote>>((ref) {
  final now = DateTime.now();
  return (ref.watch(learnNotesProvider).value ?? const [])
      .where((n) => n.reviewDueAt != null && !n.reviewDueAt!.isAfter(now))
      .toList();
});

/// A book with its note count and reviewed share, for the notebook cards.
class BookProgress {
  const BookProgress({
    required this.book,
    required this.noteCount,
    required this.reviewedCount,
  });

  final LearnBook book;
  final int noteCount;
  final int reviewedCount;

  double get ratio => noteCount == 0 ? 0 : reviewedCount / noteCount;
}

final bookProgressProvider = Provider<List<BookProgress>>((ref) {
  final books = ref.watch(learnBooksProvider).value ?? const [];
  final notes = ref.watch(learnNotesProvider).value ?? const [];

  return books.map((book) {
    final own = notes.where((n) => n.bookId == book.id).toList();
    return BookProgress(
      book: book,
      noteCount: own.length,
      reviewedCount: own.where((n) => n.lastReviewedAt != null).length,
    );
  }).toList();
});

/// One block of a note's body, as stored in `bodyJson`.
class NoteBlock {
  const NoteBlock({required this.type, required this.text});

  /// `p` | `quote` | `code` — the comp's three body treatments.
  final String type;
  final String text;

  static List<NoteBlock> decode(String json) {
    try {
      final raw = jsonDecode(json);
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => NoteBlock(
                type: (m['t'] as String?) ?? 'p',
                text: (m['text'] as String?) ?? '',
              ))
          .toList();
    } on FormatException {
      // A malformed body shouldn't take the reader down; it renders empty and
      // the title/prompt still work.
      return const [];
    }
  }

  static String encode(List<NoteBlock> blocks) {
    return jsonEncode([
      for (final b in blocks) {'t': b.type, 'text': b.text},
    ]);
  }
}

class LearnController {
  const LearnController(this._repo);

  final LearnRepository _repo;

  Future<String> addBook(String name, {String colorHex = '#4B7BA6'}) =>
      _repo.createBook(name: name, colorHex: colorHex);

  Future<String> addNote({
    required String bookId,
    required String title,
    String excerpt = '',
    List<NoteBlock> body = const [],
    String prompt = '',
    String tagsCsv = '',
    int minutes = 3,
  }) {
    return _repo.createNote(
      bookId: bookId,
      title: title,
      excerpt: excerpt,
      bodyJson: NoteBlock.encode(body),
      prompt: prompt,
      tagsCsv: tagsCsv,
      minutes: minutes,
    );
  }

  Future<void> toggleStar(LearnNote note) =>
      _repo.setStarred(note.id, !note.starred);

  Future<void> markReviewed(LearnNote note) => _repo.markReviewed(note);

  Future<void> reviewLater(LearnNote note) => _repo.reviewLater(note.id);

  Future<void> deleteNote(String id) => _repo.deleteNote(id);
}

final learnControllerProvider = Provider<LearnController>((ref) {
  return LearnController(ref.watch(learnRepositoryProvider));
});
