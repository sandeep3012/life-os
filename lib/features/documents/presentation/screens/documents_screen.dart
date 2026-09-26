import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/filter_pill.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../application/documents_providers.dart';
import '../../domain/document_type.dart';
import '../../domain/folder_icon.dart';
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
    final showingFilteredView = query.isNotEmpty || _selectedTypeFilter != null;
    // Unfiled list (no filter active): exclude docs already in a folder or
    // pinned in Quick Access — they are reachable via those entry points.
    // When a search/type filter is active, search across ALL docs so nothing
    // is hidden from the user.
    final filtered = allDocs.where((d) {
      if (!showingFilteredView) {
        if (d.isPinned) return false;       // shown in Quick Access
        if (d.folderId != null) return false; // shown in its folder
      }
      final matchesQuery = query.isEmpty || d.title.toLowerCase().contains(query);
      final matchesType = _selectedTypeFilter == null || d.documentType == _selectedTypeFilter;
      return matchesQuery && matchesType;
    }).toList();

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
          // ── Quick Access (pinned) ─────────────────────────────────────
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
                    FilterPill(
                      label: 'All',
                      selected: _selectedTypeFilter == null,
                      onTap: () => setState(() => _selectedTypeFilter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final t in DocumentType.all) ...[
                      FilterPill(
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
                childAspectRatio: 1.55,
                children: [
                  for (final f in folders)
                    FolderTile(
                      key: ValueKey(f.id),
                      folder: f,
                      count: counts[f.id] ?? 0,
                      onTap: () => context.push(
                        Uri(
                          path: '/more/documents/folder/${f.id}',
                          queryParameters: {'name': f.name},
                        ).toString(),
                      ),
                      onEdit: () => _editFolder(f),
                      onDelete: () => ref
                          .read(documentsControllerProvider)
                          .deleteFolder(f.id),
                    ),
                ],
              ),
            ),

          // ── Documents list ────────────────────────────────────────────
          _SectionHeader(
            title: showingFilteredView ? 'Results' : 'Unfiled',
            action: showingFilteredView
                ? TextButton(
                    onPressed: () => setState(() {
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
                        : showingFilteredView
                            ? 'No documents match.'
                            : 'All documents are organised into folders.',
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
    final result = await _showCreateFolderSheet(context);
    if (result == null || !mounted) return;
    await ref.read(documentsControllerProvider).createFolder(
          result.name,
          iconName: result.iconName,
          colorHex: result.colorHex,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Folder saved',
      message: '“${result.name}” is ready for documents.',
    );
  }

  Future<void> _editFolder(Folder folder) async {
    final result = await _showCreateFolderSheet(context, initial: folder);
    if (result == null || !mounted) return;
    await ref.read(documentsControllerProvider).updateFolder(
          folder.id,
          name: result.name,
          iconName: result.iconName,
          colorHex: result.colorHex,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Folder updated',
      message: 'Changes to “${result.name}” were saved.',
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
    await ref.read(documentsControllerProvider).updateDocument(
          id: document.id,
          title: details.title,
          folderId: details.folderId,
          isPinned: details.isPinned,
          documentType: details.documentType,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Document updated',
      message: 'Changes to “${details.title}” were saved.',
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
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Document saved',
      message: '“${details.title}” was added to your documents.',
    );
  }
}

enum _ImportSource { file, camera }

class _CreateFolderResult {
  const _CreateFolderResult({
    required this.name,
    required this.iconName,
    required this.colorHex,
  });
  final String name;
  final String iconName;
  final String colorHex;
}

// Palette of folder accent colours.
const _folderColors = [
  ('Ocean',    '#4B7BA6'),
  ('Terracotta', '#C2703D'),
  ('Sage',     '#3E7C5A'),
  ('Lavender', '#7C6BC4'),
  ('Teal',     '#3FA6A0'),
  ('Rose',     '#B85C6E'),
  ('Amber',    '#C49A3D'),
  ('Forest',   '#2D6B4F'),
  ('Slate',    '#5A6B7C'),
  ('Plum',     '#7A3D8C'),
  ('Coral',    '#D4624A'),
  ('Steel',    '#4A6B8C'),
];

Future<_CreateFolderResult?> _showCreateFolderSheet(
  BuildContext context, {
  Folder? initial,
}) {
  return showModalBottomSheet<_CreateFolderResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CreateFolderSheet(initial: initial),
  );
}

class _CreateFolderSheet extends StatefulWidget {
  const _CreateFolderSheet({this.initial});
  final Folder? initial;

  @override
  State<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<_CreateFolderSheet> {
  late final _controller = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late String _selectedIcon =
      widget.initial?.iconName ?? FolderIcon.general.name;
  late String _selectedColorHex =
      widget.initial?.colorHex ?? _folderColors.first.$2;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initial != null ? 'Edit folder' : 'New folder',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
          ),
          const SizedBox(height: 16),
          Text(
            'Icon',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final fi in FolderIcon.all)
                GestureDetector(
                  onTap: () => setState(() => _selectedIcon = fi.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == fi.name
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedIcon == fi.name
                          ? Border.all(
                              color: colors.primary.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          fi.icon,
                          size: 22,
                          color: _selectedIcon == fi.name
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fi.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _selectedIcon == fi.name
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Colour',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, hex) in _folderColors)
                GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Tooltip(
                    message: label,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: _selectedColorHex == hex
                            ? Border.all(
                                color: colors.onSurface,
                                width: 2.5,
                              )
                            : Border.all(color: Colors.transparent, width: 2.5),
                        boxShadow: _selectedColorHex == hex
                            ? [
                                BoxShadow(
                                  color: Color(int.parse(
                                    hex.replaceFirst('#', '0xFF'),
                                  )).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: _selectedColorHex == hex
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        _CreateFolderResult(
                          name: _controller.text.trim(),
                          iconName: _selectedIcon,
                          colorHex: _selectedColorHex,
                        ),
                      ),
              child: Text(widget.initial != null ? 'Save changes' : 'Create folder'),
            ),
          ),
        ],
      ),
    );
  }
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

