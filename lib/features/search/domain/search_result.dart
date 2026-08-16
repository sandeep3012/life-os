/// One value per underlying source, not per navigation destination — e.g.
/// transaction/bill/recurringTransaction all route to the Finance screen but
/// stay distinct here since their icons and matched fields differ.
enum SearchResultType { transaction, bill, recurringTransaction, task, note, document, goal, habit, event }

/// A single cross-module search hit. Plain immutable domain class, same
/// idiom as [CalendarItem] — not Drift-generated, built by combining several
/// repositories' data at query time.
class SearchResult {
  const SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.sourceId,
  });

  final SearchResultType type;
  final String title;
  final String subtitle;

  /// The underlying row's id — used to look up the full record (e.g. for
  /// Notes, which need more than an id to navigate to their editor) or to
  /// build a detail route (e.g. Habits).
  final String sourceId;
}
