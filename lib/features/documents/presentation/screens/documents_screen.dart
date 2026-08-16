import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../tags/application/tags_providers.dart';
import '../../application/documents_providers.dart';
import '../widgets/document_tile.dart';
import '../widgets/folder_tile.dart';
import '../widgets/quick_add_document_details_sheet.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsListProvider);
    final folders = ref.watch(documentFoldersProvider).value ?? const [];
    final counts = ref.watch(documentCountByFolderProvider);
    final query = _searchController.text.trim().toLowerCase();
    final tags = ref.watch(allTagsProvider).value ?? const [];
    final entityTags = ref.watch(allEntityTagsProvider).value ?? const [];
    final taggedDocumentIds = _selectedTagId == null
        ? null
        : {
            for (final e in entityTags)
              if (e.entityType == 'document' && e.tagId == _selectedTagId) e.entityId,
          };

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search documents',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (folders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Folders', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: folders.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final f = folders[index];
                  return SizedBox(
                    width: 84,
                    child: FolderTile(
                      folder: f,
                      count: counts[f.id] ?? 0,
                      selected: _selectedFolderId == f.id,
                      onTap: () => setState(
                        () => _selectedFolderId = _selectedFolderId == f.id ? null : f.id,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (tags.isNotEmpty) ...[
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
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Recent', style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: documentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load documents: $e')),
              data: (documents) {
                final filtered = documents.where((d) {
                  final matchesFolder =
                      _selectedFolderId == null || d.folderId == _selectedFolderId;
                  final matchesQuery = query.isEmpty || d.title.toLowerCase().contains(query);
                  final matchesTag =
                      taggedDocumentIds == null || taggedDocumentIds.contains(d.id);
                  return matchesFolder && matchesQuery && matchesTag;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        documents.isEmpty
                            ? 'No documents yet — add one to get started.'
                            : 'No documents match here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = filtered[index];
                    return DocumentTile(
                      document: d,
                      onDelete: () => ref.read(documentsControllerProvider).deleteDocument(d),
                      onTap: () => _editDocument(d),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImportSource,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _editDocument(Document document) async {
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
        .updateDocument(id: document.id, title: details.title, folderId: details.folderId);
  }

  Future<void> _pickImportSource() async {
    final source = await showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded),
              title: const Text('Import file'),
              onTap: () => Navigator.of(context).pop(_ImportSource.file),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(_ImportSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

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
    if (file == null || name == null || !mounted) return;

    final folders = ref.read(documentFoldersProvider).value ?? const [];
    final details = await showQuickAddDocumentDetailsSheet(
      context,
      suggestedTitle: p.basenameWithoutExtension(name),
      folders: folders,
    );
    if (details == null) return;

    await ref.read(documentsControllerProvider).importDocument(
      source: file,
      originalName: name,
      title: details.title,
      folderId: details.folderId,
    );
  }
}

enum _ImportSource { file, camera }
