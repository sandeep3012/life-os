import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/folder_icon.dart';

/// Grid card for a folder — sits in a 2-column SliverGrid with
/// childAspectRatio ~1.55.  Tapping navigates into the folder; long-press or
/// the ⋯ button offers deletion.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    required this.count,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Folder folder;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final folderIcon = FolderIcon.fromName(folder.iconName);
    final accentColor = folder.colorHex != null
        ? Color(int.parse(folder.colorHex!.replaceFirst('#', '0xFF')))
        : colors.documents;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(folderIcon.icon, color: accentColor, size: 20),
                  ),
                  const Spacer(),
                  if (onEdit != null || onDelete != null)
                    _FolderMenu(
                      onEdit: onEdit,
                      onDelete: onDelete != null
                          ? () => _confirmDelete(context, colors)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$count ${count == 1 ? 'document' : 'documents'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppColors colors) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Documents inside "${folder.name}" will be unassigned, not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.critical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete?.call();
  }
}

class _FolderMenu extends StatelessWidget {
  const _FolderMenu({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FolderAction>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (action) {
        switch (action) {
          case _FolderAction.edit:
            onEdit?.call();
          case _FolderAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: _FolderAction.edit,
            child: Text('Edit'),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: _FolderAction.delete,
            child: Text('Delete'),
          ),
      ],
    );
  }
}

enum _FolderAction { edit, delete }
