import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../core/database/app_database.dart';
import '../../application/documents_providers.dart';
import '../../domain/document_type.dart';
import '../widgets/document_tile.dart';
import '../widgets/folder_tile.dart';
import '../widgets/pinned_document_card.dart';
import '../widgets/quick_add_document_details_sheet.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  bool _searchVisible = false;
  String? _selectedFolderId;
  String? _selectedTypeFilter;

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
    final theme = Theme.of(context);
    final pinnedDocs = ref.watch(pinnedDocumentsProvider).value ?? const [];
    final allDocs = ref.watch(documentsListProvider).value ?? const [];
    final folders = ref.watch(documentFoldersProvider).value ?? const [];
    final counts = ref.watch(documentCountByFolderProvider);

    final query = _searchController.text.trim().toLowerCase();
    final filtered = allDocs.where((d) {
      if (d.isPinned && _selectedFolderId == null && query.isEmpty && _selectedTypeFilter == null) {
        // Pinned docs shown in Quick Access, skip in main list when no filter.
        return false;
      }
      final matchesFolder = _selectedFolderId == null || d.folderId == _selectedFolderId;
      final matchesQuery = query.isEmpty || d.title.toLowerCase().contains(query);
      final matchesType = _selectedTypeFilter == null || d.documentType == _selectedTypeFilter;
      return matchesFolder && matchesQuery && matchesType;
    }).toList();

    // When a filter is active, also include pinned docs in the list.
    final showingFilteredView =
        _selectedFolderId != null || query.isNotEmpty || _selectedTypeFilter != null;

    return Scaffold(
      drawer: const AppSidebar(),
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents…',
                  border: InputBorder.none,
                ),
              )
            : const Text('Documents'),
        actions: [
          IconButton(
            tooltip: _searchVisible ? 'Close search' : 'Search',
            icon: Icon(_searchVisible ? LucideIcons.x : LucideIcons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Quick Access (pinned) ──────────────────────────────────────
          if (pinnedDocs.isNotEmpty && !showingFilteredView) ...[
            _SectionHeader(
              title: 'Quick Access',
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: pinnedDocs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final d = pinnedDocs[i];
                    return PinnedDocumentCard(
                      key: ValueKey(d.id),
                      document: d,
                      onTap: () => _editDocument(d),
                      onUnpin: () => ref
                          .read(documentsControllerProvider)
                          .pinDocument(d.id, pinned: false),
                    );
                  },
                ),
              ),
            ),
          ],

          // ── Type filter row ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedTypeFilter == null,
                      onTap: () => setState(() => _selectedTypeFilter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final t in DocumentType.all) ...[
                      _FilterChip(
                        label: t.label,
                        icon: t.icon,
                        color: t.color,
                        selected: _selectedTypeFilter == t.value,
                        onTap: () => setState(
                          () => _selectedTypeFilter =
                              _selectedTypeFilter == t.value ? null : t.value,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Folders ───────────────────────────────────────────────────
          _SectionHeader(
            title: 'Folders',
            action: TextButton.icon(
              onPressed: _createFolder,
              icon: const Icon(LucideIcons.folderPlus, size: 14),
              label: const Text('New'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 10),
          ),

          if (folders.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Create folders to organise your documents.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  for (final f in folders)
                    FolderTile(
                      key: ValueKey(f.id),
                      folder: f,
                      count: counts[f.id] ?? 0,
                      selected: _selectedFolderId == f.id,
                      onTap: () => setState(
                        () => _selectedFolderId =
                            _selectedFolderId == f.id ? null : f.id,
                      ),
                      onDelete: () => ref
                          .read(documentsControllerProvider)
                          .deleteFolder(f.id),
                    ),
                ],
              ),
            ),

          // ── Documents list ────────────────────────────────────────────
          _SectionHeader(
            title: _selectedFolderId != null
                ? folders
                    .where((f) => f.id == _selectedFolderId)
                    .firstOrNull
                    ?.name ?? 'Documents'
                : showingFilteredView
                    ? 'Results'
                    : 'All Documents',
            action: _selectedFolderId != null || showingFilteredView
                ? TextButton(
                    onPressed: () => setState(() {
                      _selectedFolderId = null;
                      _selectedTypeFilter = null;
                      _searchController.clear();
                    }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Clear'),
                  )
                : null,
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 10),
          ),

          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Center(
                  child: Text(
                    allDocs.isEmpty
                        ? 'No documents yet — tap + Add to import one.'
                        : 'No documents match.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: DocumentTile(
                      key: ValueKey(d.id),
                      grid: false,
                      document: d,
                      onDelete: () => ref
                          .read(documentsControllerProvider)
                          .deleteDocument(d),
                      onTap: () => _editDocument(d),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImportSource,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await _promptFolderName(context);
    if (name == null || !mounted) return;
    await ref.read(documentsControllerProvider).createFolder(name);
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
    await ref.read(documentsControllerProvider).updateDocument(
          id: document.id,
          title: details.title,
          folderId: details.folderId,
          isPinned: details.isPinned,
          documentType: details.documentType,
        );
  }

  Future<void> _pickImportSource() async {
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
          isPinned: details.isPinned,
          documentType: details.documentType,
        );
  }
}

enum _ImportSource { file, camera }

/// Dialog that prompts the user to enter a folder name.
Future<String?> _promptFolderName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.of(ctx).pop(v);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

// ── Private helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.padding,
  });

  final String title;
  final Widget? action;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: effectiveColor.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? effectiveColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? effectiveColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
