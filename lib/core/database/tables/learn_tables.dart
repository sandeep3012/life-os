import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// A subject the user is studying — the comp calls these "books".
///
/// Progress is *not* stored: it's the share of this book's notes that have been
/// reviewed, derived at query time like habit streaks and budget spend.
class LearnBooks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get colorHex => text().withDefault(const Constant('#4B7BA6'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// A study note inside a [LearnBooks] subject, with the spaced-repetition
/// fields the comp's reader needs.
///
/// This is deliberately separate from the app's `Notes` table: those are
/// free-form documents in folders, whereas these carry a recall prompt, a review
/// due date and a star — a different shape with a different lifecycle.
class LearnNotes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get bookId => text().references(LearnBooks, #id)();
  TextColumn get title => text()();

  /// One-line summary shown in the list.
  TextColumn get excerpt => text().withDefault(const Constant(''))();

  /// The reader's body blocks as JSON: `[{"t":"p|quote|code","text":"..."}]`.
  /// Stored as a document because the blocks are ordered prose, never queried
  /// individually.
  TextColumn get bodyJson => text().withDefault(const Constant('[]'))();

  /// Comp: the "RECALL PROMPT" card at the end of the reader.
  TextColumn get prompt => text().withDefault(const Constant(''))();

  /// Comma-separated tags, e.g. `state,architecture`.
  TextColumn get tagsCsv => text().withDefault(const Constant(''))();

  /// Estimated read time in minutes.
  IntColumn get minutes => integer().withDefault(const Constant(3))();

  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// When this note next wants reviewing. Null means "not scheduled".
  DateTimeColumn get reviewDueAt => dateTime().nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
