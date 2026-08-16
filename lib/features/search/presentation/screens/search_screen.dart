import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../goals/presentation/screens/goal_detail_screen.dart';
import '../../../notes/application/notes_providers.dart';
import '../../../notes/presentation/screens/note_editor_screen.dart';
import '../../application/search_providers.dart';
import '../../domain/search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
              decoration: const InputDecoration(
                hintText: 'Search everything',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? Center(
                    child: Text(
                      'Search tasks, notes, transactions, and more',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : results.isEmpty
                ? Center(
                    child: Text(
                      'No results for "${query.trim()}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return _SearchResultTile(
                        result: result,
                        onTap: () => _openResult(context, ref, result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResult(BuildContext context, WidgetRef ref, SearchResult result) async {
    switch (result.type) {
      case SearchResultType.habit:
        context.push(RoutePaths.habitDetail(result.sourceId));
      case SearchResultType.note:
        final notes = ref.read(notesListProvider).value ?? const [];
        final note = notes.where((n) => n.id == result.sourceId).firstOrNull;
        if (note == null) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
      case SearchResultType.goal:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: result.sourceId)));
      case SearchResultType.transaction:
      case SearchResultType.bill:
      case SearchResultType.recurringTransaction:
        context.go(RoutePaths.finance);
      case SearchResultType.task:
        context.go(RoutePaths.tasksHabits);
      case SearchResultType.document:
        context.go(RoutePaths.documents);
      case SearchResultType.event:
        context.go(RoutePaths.calendar);
    }
  }
}

(IconData, Color) _iconAndColor(BuildContext context, SearchResultType type) {
  final colors = context.appColors;
  return switch (type) {
    SearchResultType.transaction => (Icons.swap_horiz_rounded, colors.finance),
    SearchResultType.bill => (Icons.receipt_long_rounded, colors.finance),
    SearchResultType.recurringTransaction => (Icons.autorenew_rounded, colors.finance),
    SearchResultType.task => (Icons.check_circle_outline_rounded, colors.tasks),
    SearchResultType.note => (Icons.note_alt_rounded, colors.notes),
    SearchResultType.document => (Icons.folder_copy_rounded, colors.documents),
    SearchResultType.goal => (Icons.flag_rounded, colors.goals),
    SearchResultType.habit => (Icons.repeat_rounded, colors.habits),
    SearchResultType.event => (Icons.event_rounded, colors.calendar),
  };
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _iconAndColor(context, result.type);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(result.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        result.subtitle,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
