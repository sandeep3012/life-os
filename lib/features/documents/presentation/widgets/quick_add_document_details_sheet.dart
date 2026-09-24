import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../tags/presentation/widgets/tag_chip_row.dart';
import '../../domain/document_type.dart';

class QuickAddDocumentDetails {
  const QuickAddDocumentDetails({
    required this.title,
    this.folderId,
    this.isPinned = false,
    this.documentType,
  });

  final String title;
  final String? folderId;
  final bool isPinned;
  final String? documentType;
}

Future<QuickAddDocumentDetails?> showQuickAddDocumentDetailsSheet(
  BuildContext context, {
  required String suggestedTitle,
  required List<Folder> folders,
  Document? initial,
}) {
  return showModalBottomSheet<QuickAddDocumentDetails>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DetailsSheet(
      suggestedTitle: suggestedTitle,
      folders: folders,
      initial: initial,
    ),
  );
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({
    required this.suggestedTitle,
    required this.folders,
    this.initial,
  });

  final String suggestedTitle;
  final List<Folder> folders;
  final Document? initial;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final _titleController = TextEditingController(
    text: widget.initial?.title ?? widget.suggestedTitle,
  );
  late String? _folderId = widget.initial?.folderId;
  late bool _isPinned = widget.initial?.isPinned ?? false;
  late String? _documentType = widget.initial?.documentType;

  bool get _isEditMode => widget.initial != null;

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
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit document' : 'Save document',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 16),
            // Document type
            Text(
              'Type',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in DocumentType.all)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 14, color: _documentType == t.value ? t.color : null),
                    label: Text(t.label),
                    selected: _documentType == t.value,
                    onSelected: (_) => setState(
                      () => _documentType = _documentType == t.value ? null : t.value,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Pin to Quick Access
            InkWell(
              onTap: () => setState(() => _isPinned = !_isPinned),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.pin,
                      size: 16,
                      color: _isPinned
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pin to Quick Access',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Show this document at the top of your Documents screen',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPinned,
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.folders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Folder',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
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
            if (widget.initial != null) ...[
              const SizedBox(height: 12),
              TagChipRow(entityType: 'document', entityId: widget.initial!.id),
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
                          isPinned: _isPinned,
                          documentType: _documentType,
                        ),
                      ),
                child: Text(_isEditMode ? 'Save changes' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
