import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_utils.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../documents/application/documents_providers.dart';
import '../../finance/application/finance_providers.dart';
import '../../goals/application/goals_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../notes/application/notes_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../domain/search_result.dart';

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

/// Combines all 9 searchable sources into one flat list — an in-memory
/// filter over data already resident in the provider container (every
/// upstream stream already has other screens watching it), so no debounce
/// is needed; matches `notes_screen.dart`'s existing filter-on-every-keystroke
/// precedent.
final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];

  bool matches(String s) => s.toLowerCase().contains(query);

  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final bills = ref.watch(billsProvider).value ?? const [];
  final recurring = ref.watch(recurringTransactionsProvider).value ?? const [];
  final tasks = ref.watch(allTasksProvider).value ?? const [];
  final notes = ref.watch(notesListProvider).value ?? const [];
  final documents = ref.watch(documentsListProvider).value ?? const [];
  final goals = ref.watch(goalsListProvider).value ?? const [];
  final habits = ref.watch(habitsListProvider).value ?? const [];
  final events = ref.watch(manualEventsProvider).value ?? const [];

  return [
    for (final t in transactions)
      if (matches(t.merchant) || (t.note != null && matches(t.note!)))
        SearchResult(
          type: SearchResultType.transaction,
          title: t.merchant,
          subtitle: '${formatMinor(t.amountMinor, showSign: t.amountMinor >= 0)} · ${DateFormat.MMMd().format(t.date)}',
          sourceId: t.id,
        ),
    for (final b in bills)
      if (matches(b.name))
        SearchResult(
          type: SearchResultType.bill,
          title: b.name,
          subtitle: '${formatMinor(b.amountMinor)} · due ${DateFormat.MMMd().format(b.dueDate)}',
          sourceId: b.id,
        ),
    for (final r in recurring)
      if (matches(r.merchant) || (r.note != null && matches(r.note!)))
        SearchResult(
          type: SearchResultType.recurringTransaction,
          title: r.merchant,
          subtitle: '${formatMinor(r.amountMinor)} · ${r.frequency}',
          sourceId: r.id,
        ),
    for (final task in tasks)
      if (matches(task.title))
        SearchResult(
          type: SearchResultType.task,
          title: task.title,
          subtitle: task.dueDate != null ? 'Due ${DateFormat.MMMd().format(task.dueDate!)}' : 'No due date',
          sourceId: task.id,
        ),
    for (final n in notes)
      if (matches(n.title) || matches(n.body))
        SearchResult(
          type: SearchResultType.note,
          title: n.title.isEmpty ? 'Untitled' : n.title,
          subtitle: 'Note',
          sourceId: n.id,
        ),
    for (final d in documents)
      if (matches(d.title))
        SearchResult(type: SearchResultType.document, title: d.title, subtitle: 'Document', sourceId: d.id),
    for (final g in goals)
      if (matches(g.title))
        SearchResult(type: SearchResultType.goal, title: g.title, subtitle: 'Goal', sourceId: g.id),
    for (final h in habits)
      if (matches(h.name))
        SearchResult(type: SearchResultType.habit, title: h.name, subtitle: 'Habit', sourceId: h.id),
    for (final e in events)
      if (matches(e.title))
        SearchResult(
          type: SearchResultType.event,
          title: e.title,
          subtitle: DateFormat.MMMd().add_jm().format(e.startTime),
          sourceId: e.id,
        ),
  ];
});
