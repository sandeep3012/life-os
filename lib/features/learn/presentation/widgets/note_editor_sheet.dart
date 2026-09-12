import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/learn_providers.dart';

/// Captures a study note: which notebook it belongs to (picking or creating
/// one), a title, the body, a recall prompt and tags.
///
/// The body is entered as plain text and stored as a single prose block; the
/// reader's quote and code treatments exist in the model for richer notes, and
/// this sheet keeps capture fast rather than exposing a block editor.
class NoteEditorSheet extends ConsumerStatefulWidget {
  const NoteEditorSheet({super.key});

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _prompt = TextEditingController();
  final _tags = TextEditingController();
  final _newBook = TextEditingController();

  String? _bookId;
  bool _creatingBook = false;

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

    final body = _body.text.trim();
    await controller.addNote(
      bookId: bookId,
      title: title,
      excerpt: body.length > 140 ? '${body.substring(0, 140)}…' : body,
      body: body.isEmpty ? const [] : [NoteBlock(type: 'p', text: body)],
      prompt: _prompt.text.trim(),
      tagsCsv: _tags.text.trim(),
      minutes: (body.split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 60),
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final books = ref.watch(learnBooksProvider).value ?? const [];
    final needsNewBook = _creatingBook || books.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New note',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
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
                              onPressed: () =>
                                  setState(() => _creatingBook = false),
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
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save note'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showNoteEditorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const NoteEditorSheet(),
  );
}
