import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart' show Document;
import '../../../../core/widgets/save_feedback.dart';
import '../../application/documents_providers.dart';
import '../widgets/document_tile.dart';
import '../widgets/quick_add_document_details_sheet.dart';

/// Shows all documents inside a single folder and lets the user add more.
class FolderDocumentsScreen extends ConsumerWidget {
  const FolderDocumentsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allDocs = ref.watch(documentsListProvider).value ?? const [];
    final folderDocs = allDocs.where((d) => d.folderId == folderId).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(folderName),
      ),
      body: folderDocs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No documents in this folder yet.\nTap + Add to import one.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: folderDocs.length,
              itemBuilder: (context, i) {
                final d = folderDocs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DocumentTile(
                    key: ValueKey(d.id),
                    grid: false,
                    document: d,
                    onDelete: () =>
                        ref.read(documentsControllerProvider).deleteDocument(d),
                    onTap: () => _editDocument(context, ref, d),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickImportSource(context, ref),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _editDocument(
      BuildContext context, WidgetRef ref, Document document) async {
    final folders = ref.read(documentFoldersProvider).value ?? const [];
    final details = await showQuickAddDocumentDetailsSheet(
      context,
      suggestedTitle: document.title,
      folders: folders,
      initial: document,
    );
    if (details == null) return;
    await ref.read(documentsControllerProvider).updateDocument(
          id: document.id,
          title: details.title,
          folderId: details.folderId,
          isPinned: details.isPinned,
          documentType: details.documentType,
        );
    if (!context.mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Document updated',
      message: 'Changes to “${details.title}” were saved.',
    );
  }

  Future<void> _pickImportSource(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.file),
              title: const Text('Import file'),
              onTap: () => Navigator.of(context).pop(_ImportSource.file),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(_ImportSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    File? file;
    String? name;
    switch (source) {
      case _ImportSource.file:
        final result = await FilePicker.pickFiles();
        final picked = result?.files.single;
        if (picked?.path != null) {
          file = File(picked!.path!);
          name = picked.name;
        }
      case _ImportSource.camera:
        final picked = await ImagePicker().pickImage(source: ImageSource.camera);
        if (picked != null) {
          file = File(picked.path);
          name = p.basename(picked.path);
        }
    }
    if (file == null || name == null || !context.mounted) return;

    final folders = ref.read(documentFoldersProvider).value ?? const [];
    final details = await showQuickAddDocumentDetailsSheet(
      context,
      suggestedTitle: p.basenameWithoutExtension(name),
      folders: folders,
      defaultFolderId: folderId,
    );
    if (details == null) return;

    await ref.read(documentsControllerProvider).importDocument(
          source: file,
          originalName: name,
          title: details.title,
          folderId: details.folderId ?? folderId,
          isPinned: details.isPinned,
          documentType: details.documentType,
        );
    if (!context.mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Document saved',
      message: '“${details.title}” was added to $folderName.',
    );
  }
}

enum _ImportSource { file, camera }
