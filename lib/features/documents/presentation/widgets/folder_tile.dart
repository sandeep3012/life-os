import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';

/// Grid card for a folder — designed for a 2-column SliverGrid.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final Folder folder;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? colors.documents.withValues(alpha: 0.12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: colors.documents.withValues(alpha: 0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete != null
            ? () => _confirmDelete(context, colors)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.documents.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.folderOpen,
                      color: colors.documents,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    GestureDetector(
                      onTap: () => _confirmDelete(context, colors),
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
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
