import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../tags/presentation/widgets/tag_chip_row.dart';
import '../../application/notes_providers.dart';

enum _SaveStatus { saved, unsaved, saving }

/// Full screen (not a sheet) since notes need room for multi-line body
/// editing — pass [note] to edit an existing one, or omit to create new.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note, this.initialFolderId});

  final Note? note;
  final String? initialFolderId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  static const _autosaveDelay = Duration(milliseconds: 800);

  late final _titleController = TextEditingController(text: widget.note?.title ?? '');
  late final _bodyController = TextEditingController(text: widget.note?.body ?? '');
  String? _folderId;

  /// The note's id once it exists in the DB — starts as [widget.note]'s id
  /// for an edit, or null for a brand-new note until the first autosave (or
  /// manual Save) creates the row. [widget.note] itself never changes (it's
  /// a `final` constructor field), so this is what both autosave and the
  /// delete affordance key off of once a new note has been created.
  String? _noteId;
  Timer? _debounce;
  _SaveStatus _status = _SaveStatus.saved;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id;
    _folderId = widget.note?.folderId ?? widget.initialFolderId;
    _titleController.addListener(_onEdited);
    _bodyController.addListener(_onEdited);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onEdited() {
    _debounce?.cancel();
    if (_status != _SaveStatus.unsaved) setState(() => _status = _SaveStatus.unsaved);
    _debounce = Timer(_autosaveDelay, _persist);
  }

  /// Creates the note on its first successful save, updates it on every
  /// save after that. A blank title is left alone (no half-formed note
  /// created just because the user tapped into the body field first).
  Future<void> _persist() async {
    _debounce?.cancel();
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (mounted) setState(() => _status = _SaveStatus.saving);
    final controller = ref.read(notesControllerProvider);
    if (_noteId == null) {
      final id = await controller.createNote(
        title: title,
        body: _bodyController.text,
        folderId: _folderId,
      );
      _noteId = id;
    } else {
      await controller.updateNote(
        id: _noteId!,
        title: title,
        body: _bodyController.text,
        folderId: _folderId,
      );
    }
    if (mounted) setState(() => _status = _SaveStatus.saved);
  }

  Future<void> _saveAndClose() async {
    await _persist();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _debounce?.cancel();
    if (_noteId != null) await ref.read(notesControllerProvider).deleteNote(_noteId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(noteFoldersProvider).value ?? const [];
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _persist();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New note' : 'Edit note'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(18),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  switch (_status) {
                    _SaveStatus.saved => _noteId == null ? '' : 'Saved',
                    _SaveStatus.unsaved => 'Unsaved changes…',
                    _SaveStatus.saving => 'Saving…',
                  },
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (_noteId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
            TextButton(onPressed: _saveAndClose, child: const Text('Save')),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: widget.note == null,
                style: theme.textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
              if (folders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('No folder'),
                      selected: _folderId == null,
                      onSelected: (_) {
                        setState(() => _folderId = null);
                        _onEdited();
                      },
                    ),
                    for (final f in folders)
                      ChoiceChip(
                        label: Text(f.name),
                        selected: _folderId == f.id,
                        onSelected: (_) {
                          setState(() => _folderId = f.id);
                          _onEdited();
                        },
                      ),
                  ],
                ),
              ],
              if (_noteId != null) ...[
                const SizedBox(height: 12),
                TagChipRow(entityType: 'note', entityId: _noteId!),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Start typing…',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
