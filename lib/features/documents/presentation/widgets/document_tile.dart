import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';

IconData _iconForMime(String mime) {
  if (mime.startsWith('image/')) return LucideIcons.image;
  if (mime == 'application/pdf') return LucideIcons.fileText;
  return LucideIcons.fileText;
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onDelete,
    this.onTap,
    this.grid = false,
  });

  final Document document;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isImage = document.mimeType.startsWith('image/');
    final color = document.mimeType == 'application/pdf'
        ? colors.critical
        : colors.info;

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: colors.critical.withValues(alpha: 0.15),
        child: Icon(LucideIcons.trash2, color: colors.critical),
      ),
      child: grid
          ? Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isImage && document.thumbnailPath != null
                            ? _Thumbnail(
                                relativePath: document.thumbnailPath!,
                                size: 64,
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                color: color.withValues(alpha: 0.14),
                                child: Icon(
                                  _iconForMime(document.mimeType),
                                  size: 30,
                                  color: color,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        document.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatSize(document.sizeBytes)} · ${DateFormat.MMMd().format(document.createdAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: isImage && document.thumbnailPath != null
                          ? _Thumbnail(relativePath: document.thumbnailPath!)
                          : Container(
                              width: 38,
                              height: 38,
                              color: color.withValues(alpha: 0.14),
                              child: Icon(
                                _iconForMime(document.mimeType),
                                size: 18,
                                color: color,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_formatSize(document.sizeBytes)} · ${DateFormat.MMMd().format(document.createdAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.relativePath, this.size = 38});

  final String relativePath;
  final double size;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  final _storage = FileStorageService();
  File? _file;

  @override
  void initState() {
    super.initState();
    _storage.absoluteFile(widget.relativePath).then((f) {
      if (mounted) setState(() => _file = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return Image.file(
      _file!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          SizedBox(width: widget.size, height: widget.size),
    );
  }
}
