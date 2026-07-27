import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';

IconData _iconForMime(String mime) {
  if (mime.startsWith('image/')) return Icons.image_rounded;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
  return Icons.description_rounded;
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.document, required this.onDelete});

  final Document document;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isImage = document.mimeType.startsWith('image/');
    final color = document.mimeType == 'application/pdf' ? colors.critical : colors.info;

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: colors.critical.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline_rounded, color: colors.critical),
      ),
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
                      child: Icon(_iconForMime(document.mimeType), size: 18, color: color),
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
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.relativePath});

  final String relativePath;

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
      return const SizedBox(width: 38, height: 38);
    }
    return Image.file(
      _file!,
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox(width: 38, height: 38),
    );
  }
}
