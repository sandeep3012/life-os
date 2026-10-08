import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart' show Document, Folder;
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../application/documents_providers.dart';
import '../../domain/folder_tree.dart';
import '../widgets/document_tile.dart';
import '../widgets/folder_editor_sheet.dart';
import '../widgets/folder_tile.dart';
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
    final folders = ref.watch(documentFoldersProvider).value ?? const [];
    final counts = ref.watch(documentCountByFolderProvider);
    final folderDocs = allDocs.where((d) => d.folderId == folderId).toList();
    final subfolders = FolderTree.childrenOf(folders, folderId);
    final current = folders.where((f) => f.id == folderId).firstOrNull;
    // The name as it is now (it may have been renamed since this opened),
    // and where it sits when it's inside another folder.
    final title = current?.name ?? folderName;
    final parentPath = current?.parentFolderId == null
        ? null
        : FolderTree.pathOf(folders, current!.parentFolderId!);

    return InlineAddHost(
      builder: (context, inlineAddVisible, onInlineAddVisibility) => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (parentPath != null)
                Text(
                  'In $parentPath',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New folder',
              icon: const Icon(LucideIcons.folderPlus),
              onPressed: () => _createSubfolder(context, ref),
            ),
          ],
        ),
        body: folderDocs.isEmpty && subfolders.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This folder is empty.\nAdd a document, or a folder to '
                        'organise them further.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _createSubfolder(context, ref),
                            icon: const Icon(LucideIcons.folderPlus, size: 18),
                            label: const Text('New folder'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _pickImportSource(context, ref),
                            icon: const Icon(LucideIcons.filePlus, size: 18),
                            label: const Text('Add document'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (subfolders.isNotEmpty) ...[
                    _Heading('Folders'),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final f in subfolders)
                          FolderTile(
                            key: ValueKey(f.id),
                            folder: f,
                            count: counts[f.id] ?? 0,
                            folderCount: FolderTree.childrenOf(
                              folders,
                              f.id,
                            ).length,
                            onTap: () => context.push(
                              Uri(
                                path: '/more/documents/folder/${f.id}',
                                queryParameters: {'name': f.name},
                              ).toString(),
                            ),
                            onEdit: () => _editFolder(context, ref, f),
                            onDelete: () => ref
                                .read(documentsControllerProvider)
                                .deleteFolder(f.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Heading('Documents'),
                  ],
                  for (final d in folderDocs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: DocumentTile(
                        key: ValueKey(d.id),
                        grid: false,
                        document: d,
                        onDelete: () => ref
                            .read(documentsControllerProvider)
                            .deleteDocument(d),
                        onTap: () => _editDocument(context, ref, d),
                      ),
                    ),
                  InlineAddButton(
                    label: 'Add document',
                    onTap: () => _pickImportSource(context, ref),
                    onVisibilityChanged: onInlineAddVisibility,
                    padding: const EdgeInsets.only(top: 12),
                  ),
                ],
              ),
        // One add affordance at a time: the dashed row at the end of the list
        // while it is on screen, the FAB once it has scrolled away.
        floatingActionButton: inlineAddVisible
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _pickImportSource(context, ref),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add'),
              ),
      ),
    );
  }

  Future<void> _createSubfolder(BuildContext context, WidgetRef ref) async {
    final result = await showFolderEditorSheet(context);
    if (result == null) return;
    await ref
        .read(documentsControllerProvider)
        .createFolder(
          result.name,
          iconName: result.iconName,
          colorHex: result.colorHex,
          parentFolderId: folderId,
        );
    if (!context.mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Folder saved',
      message: '“${result.name}” is inside $folderName.',
    );
  }

  Future<void> _editFolder(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final result = await showFolderEditorSheet(context, initial: folder);
    if (result == null) return;
    await ref
        .read(documentsControllerProvider)
        .updateFolder(
          folder.id,
          name: result.name,
          iconName: result.iconName,
          colorHex: result.colorHex,
        );
  }

  Future<void> _editDocument(
    BuildContext context,
    WidgetRef ref,
    Document document,
  ) async {
    final folders = ref.read(documentFoldersProvider).value ?? const [];
    final details = await showQuickAddDocumentDetailsSheet(
      context,
      suggestedTitle: document.title,
      folders: folders,
      initial: document,
    );
    if (details == null) return;
    await ref
        .read(documentsControllerProvider)
        .updateDocument(
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
            ListTile(
              leading: const Icon(LucideIcons.folderPlus),
              title: const Text('New folder'),
              onTap: () => Navigator.of(context).pop(_ImportSource.folder),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    if (source == _ImportSource.folder) {
      await _createSubfolder(context, ref);
      return;
    }

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
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );
        if (picked != null) {
          file = File(picked.path);
          name = p.basename(picked.path);
        }
      case _ImportSource.folder:
        return; // Handled above.
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

    await ref
        .read(documentsControllerProvider)
        .importDocument(
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

enum _ImportSource { file, camera, folder }

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
