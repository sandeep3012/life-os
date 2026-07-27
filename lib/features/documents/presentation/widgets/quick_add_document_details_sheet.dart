import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class QuickAddDocumentDetails {
  const QuickAddDocumentDetails({required this.title, this.folderId});

  final String title;
  final String? folderId;
}

Future<QuickAddDocumentDetails?> showQuickAddDocumentDetailsSheet(
  BuildContext context, {
  required String suggestedTitle,
  required List<Folder> folders,
}) {
  return showModalBottomSheet<QuickAddDocumentDetails>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DetailsSheet(suggestedTitle: suggestedTitle, folders: folders),
  );
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({required this.suggestedTitle, required this.folders});

  final String suggestedTitle;
  final List<Folder> folders;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final _titleController = TextEditingController(text: widget.suggestedTitle);
  String? _folderId;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Save document', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          if (widget.folders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No folder'),
                  selected: _folderId == null,
                  onSelected: (_) => setState(() => _folderId = null),
                ),
                for (final f in widget.folders)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: _folderId == f.id,
                    onSelected: (_) => setState(() => _folderId = f.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      QuickAddDocumentDetails(
                        title: _titleController.text.trim(),
                        folderId: _folderId,
                      ),
                    ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
