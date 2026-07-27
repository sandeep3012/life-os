import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../application/notes_providers.dart';

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
  late final _titleController = TextEditingController(text: widget.note?.title ?? '');
  late final _bodyController = TextEditingController(text: widget.note?.body ?? '');
  String? _folderId;

  @override
  void initState() {
    super.initState();
    _folderId = widget.note?.folderId ?? widget.initialFolderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final controller = ref.read(notesControllerProvider);
    if (widget.note == null) {
      await controller.createNote(
        title: title,
        body: _bodyController.text,
        folderId: _folderId,
      );
    } else {
      await controller.updateNote(
        id: widget.note!.id,
        title: title,
        body: _bodyController.text,
        folderId: _folderId,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(noteFoldersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Edit note'),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await ref.read(notesControllerProvider).deleteNote(widget.note!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
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
              style: Theme.of(context).textTheme.titleLarge,
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
                    onSelected: (_) => setState(() => _folderId = null),
                  ),
                  for (final f in folders)
                    ChoiceChip(
                      label: Text(f.name),
                      selected: _folderId == f.id,
                      onSelected: (_) => setState(() => _folderId = f.id),
                    ),
                ],
              ),
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
    );
  }
}
