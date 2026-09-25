import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/learn_providers.dart';

/// Captures a study note — or edits one when [initial] is set: which notebook
/// it belongs to (picking or creating one), a title, the body, a recall prompt
/// and tags.
///
/// The body is a single text field over the note's blocks, round-tripped
/// through [NoteBlock.toEditableText] so quotes (`> `) and code (``` fences)
/// survive an edit instead of being flattened into prose.
class NoteEditorSheet extends ConsumerStatefulWidget {
  const NoteEditorSheet({super.key, this.initial});

  final LearnNote? initial;

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _body = TextEditingController(
    text: widget.initial == null
        ? null
        : NoteBlock.toEditableText(NoteBlock.decode(widget.initial!.bodyJson)),
  );
  late final _prompt = TextEditingController(text: widget.initial?.prompt);
  late final _tags = TextEditingController(text: widget.initial?.tagsCsv);
  final _newBook = TextEditingController();

  late String? _bookId = widget.initial?.bookId;
  bool _creatingBook = false;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _prompt.dispose();
    _tags.dispose();
    _newBook.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final controller = ref.read(learnControllerProvider);

    var bookId = _bookId;
    if (_creatingBook || bookId == null) {
      final name = _newBook.text.trim();
      if (name.isEmpty) return;
      bookId = await controller.addBook(name);
    }

    final blocks = NoteBlock.fromEditableText(_body.text.trim());
    // The excerpt and read time come from the words, not the markup, so a
    // leading quote or code fence doesn't leak `>` or ``` into the list.
    final plain = blocks.map((b) => b.text).join(' ').trim();
    final excerpt = plain.length > 140 ? '${plain.substring(0, 140)}…' : plain;
    final minutes = plain.isEmpty
        ? 1
        : (plain.split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 60);

    if (_isEditing) {
      await controller.updateNote(
        id: widget.initial!.id,
        bookId: bookId,
        title: title,
        excerpt: excerpt,
        body: blocks,
        prompt: _prompt.text.trim(),
        tagsCsv: _tags.text.trim(),
        minutes: minutes,
      );
    } else {
      await controller.addNote(
        bookId: bookId,
        title: title,
        excerpt: excerpt,
        body: blocks,
        prompt: _prompt.text.trim(),
        tagsCsv: _tags.text.trim(),
        minutes: minutes,
      );
    }

    if (mounted) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final books = ref.watch(learnBooksProvider).value ?? const [];
    final needsNewBook = _creatingBook || books.isEmpty;

    return CompactEditorSheet(
      title: _isEditing ? 'Edit note' : 'New note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),

          Text(
            'Notebook',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (needsNewBook)
            TextField(
              controller: _newBook,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Notebook name',
                suffixIcon: books.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Pick an existing notebook',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(() => _creatingBook = false),
                      ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final book in books)
                  Tappable(
                    haptic: TapHaptic.selection,
                    semanticLabel: book.name,
                    selected: book.id == _bookId,
                    onTap: () => setState(() => _bookId = book.id),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: book.id == _bookId
                            ? colors.accentSoft
                            : scheme.surface,
                        border: Border.all(
                          color: book.id == _bookId
                              ? scheme.secondary
                              : scheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        book.name,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: book.id == _bookId
                              ? colors.accentInk
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                Tappable(
                  haptic: TapHaptic.light,
                  semanticLabel: 'New notebook',
                  onTap: () => setState(() => _creatingBook = true),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+ New',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              // The markup is the only way to keep quotes and code apart in a
              // single field, so it has to be discoverable here.
              helperText: 'Start a line with > for a quote; wrap code in ```',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prompt,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Recall prompt',
              hintText: 'What question should this answer later?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'comma, separated',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Save note'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showNoteEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  LearnNote? initial,
}) async {
  final saved = await showCompactEditorSheet<String>(
    context: context,
    builder: (context) => NoteEditorSheet(initial: initial),
  );
  if (saved == null || !context.mounted) return;
  await showSaveFeedback(
    context,
    ref,
    title: initial == null ? 'Note saved' : 'Note updated',
    message: initial == null
        ? '“$saved” is in your notebook.'
        : 'Changes to “$saved” were saved.',
  );
}
