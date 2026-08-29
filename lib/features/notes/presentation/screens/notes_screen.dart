import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tags/application/tags_providers.dart';
import '../../application/notes_providers.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String? _selectedFolderId;
  String? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notesListProvider);
    await ref.read(notesListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final folders = ref.watch(noteFoldersProvider).value ?? const [];
    final folderById = {for (final f in folders) f.id: f};
    final query = _searchController.text.trim().toLowerCase();
    final tags = ref.watch(allTagsProvider).value ?? const [];
    final entityTags = ref.watch(allEntityTagsProvider).value ?? const [];
    final taggedNoteIds = _selectedTagId == null
        ? null
        : {
            for (final e in entityTags)
              if (e.entityType == 'note' && e.tagId == _selectedTagId) e.entityId,
          };

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(_searchController.clear),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFolderId == null,
                    onSelected: (_) => setState(() => _selectedFolderId = null),
                  ),
                ),
                for (final f in folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.name),
                      selected: _selectedFolderId == f.id,
                      onSelected: (_) => setState(() => _selectedFolderId = f.id),
                    ),
                  ),
              ],
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t.name),
                        selected: _selectedTagId == t.id,
                        onSelected: (_) => setState(
                          () => _selectedTagId = _selectedTagId == t.id ? null : t.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load notes: $e')),
              data: (notes) {
                final filtered = notes.where((n) {
                  final matchesFolder =
                      _selectedFolderId == null || n.folderId == _selectedFolderId;
                  final matchesQuery =
                      query.isEmpty ||
                      n.title.toLowerCase().contains(query) ||
                      n.body.toLowerCase().contains(query);
                  final matchesTag = taggedNoteIds == null || taggedNoteIds.contains(n.id);
                  return matchesFolder && matchesQuery && matchesTag;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              notes.isEmpty
                                  ? 'No notes yet — add one to get started.'
                                  : 'No notes match your search.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.1, end: 0, duration: 250.ms),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      return NoteCard(
                        note: note,
                        folder: folderById[note.folderId],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                        ),
                      )
                          .animate(delay: (index * 25).ms)
                          .fadeIn(duration: 200.ms)
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.0, 1.0),
                            duration: 200.ms,
                            curve: Curves.easeOutBack,
                          );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(initialFolderId: _selectedFolderId),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }
}
