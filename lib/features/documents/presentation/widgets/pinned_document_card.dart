import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../domain/document_type.dart';

/// Large horizontal card for the Quick Access strip.
class PinnedDocumentCard extends StatelessWidget {
  const PinnedDocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onUnpin,
  });

  final Document document;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docType = DocumentType.fromValue(document.documentType);
    final accentColor = docType?.color ?? const Color(0xFF4B7BA6);
    final icon = docType?.icon ?? LucideIcons.file;
    final isImage = document.mimeType.startsWith('image/');

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured header band
              Container(
                height: 80,
                color: accentColor.withValues(alpha: 0.12),
                child: Stack(
                  children: [
                    // Thumbnail or icon
                    Positioned.fill(
                      child: isImage && document.thumbnailPath != null
                          ? _CardThumbnail(relativePath: document.thumbnailPath!)
                          : Center(
                              child: Icon(icon, size: 36, color: accentColor),
                            ),
                    ),
                    // Unpin button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onUnpin,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.pinOff,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Card body
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (docType != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              docType.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          DateFormat.MMMd().format(document.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
}

class _CardThumbnail extends StatefulWidget {
  const _CardThumbnail({required this.relativePath});

  final String relativePath;

  @override
  State<_CardThumbnail> createState() => _CardThumbnailState();
}

class _CardThumbnailState extends State<_CardThumbnail> {
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
    if (_file == null) return const SizedBox.shrink();
    return Image.file(
      _file!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
