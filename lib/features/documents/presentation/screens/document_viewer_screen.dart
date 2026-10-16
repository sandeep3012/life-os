import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/widgets/undo_snack_bar.dart';
import '../../application/documents_providers.dart';

/// Opens [document]: a PDF or an image in the app's own viewer, anything
/// else (Word, Excel, …) in whichever app on the phone handles it. [onEdit]
/// is the viewer's Edit button — the list's long-press does the same.
Future<void> openDocument(
  BuildContext context,
  WidgetRef ref,
  Document document, {
  required VoidCallback onEdit,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final file = await ref
      .read(fileStorageServiceProvider)
      .absoluteFile(document.filePath);
  final exists = await file.exists();
  if (!context.mounted) return;

  final viewable =
      document.mimeType == 'application/pdf' ||
      document.mimeType.startsWith('image/');
  if (viewable || !exists) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(
          document: document,
          file: exists ? file : null,
          onEdit: onEdit,
        ),
      ),
    );
    return;
  }
  final message = await openInOtherApp(file);
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Swipe-to-delete: gone at once, with "Document deleted · Undo".
Future<void> deleteDocumentWithUndo(
  BuildContext context,
  WidgetRef ref,
  Document document,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(documentsControllerProvider);
  final removed = await controller.deleteDocument(document);
  showUndoSnackBar(
    messenger,
    message: 'Document deleted',
    onUndo: () => controller.restore(removed),
  );
}

/// Hands [file] to the phone's own app for its type. Returns what to tell
/// the person when that didn't work, or null when it opened.
Future<String?> openInOtherApp(File file) async {
  try {
    final result = await OpenFilex.open(file.path);
    return switch (result.type) {
      ResultType.done => null,
      ResultType.noAppToOpen => 'No app on this phone can open this file.',
      ResultType.fileNotFound => "This file isn't on this phone.",
      ResultType.permissionDenied => 'LifeOS isn\'t allowed to open this file.',
      ResultType.error => "Couldn't open this file.",
    };
  } catch (_) {
    return "Couldn't open this file.";
  }
}

class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({
    super.key,
    required this.document,
    required this.file,
    required this.onEdit,
  });

  final Document document;

  /// Null when the file isn't on this phone — say, a document that arrived
  /// through sync, which carries the record but not the file.
  final File? file;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (file != null)
            IconButton(
              tooltip: 'Open in another app',
              icon: const Icon(LucideIcons.externalLink),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final message = await openInOtherApp(file);
                if (message != null) {
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
          IconButton(
            tooltip: 'Edit details',
            icon: const Icon(LucideIcons.pencil),
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
          ),
        ],
      ),
      body: file == null
          ? const _Missing()
          : document.mimeType == 'application/pdf'
          ? _PdfView(file: file)
          : document.mimeType.startsWith('image/')
          ? PhotoView(
              imageProvider: FileImage(file),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              backgroundDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              errorBuilder: (_, _, _) =>
                  const _Problem("This image couldn't be shown."),
            )
          : _Problem(
              'This kind of file opens in another app.',
              action: TextButton(
                onPressed: () => openInOtherApp(file),
                child: const Text('Open'),
              ),
            ),
    );
  }
}

class _PdfView extends StatefulWidget {
  const _PdfView({required this.file});

  final File file;

  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  late final _controller = PdfControllerPinch(
    document: PdfDocument.openFile(widget.file.path),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(
    controller: _controller,
    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
      options: const DefaultBuilderOptions(),
      documentLoaderBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      pageLoaderBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _) => const _Problem("This PDF couldn't be opened."),
    ),
  );
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => const _Problem(
    "This file isn't on this phone. Its details are here, but the file "
    'itself was added on another device or has been removed.',
  );
}

class _Problem extends StatelessWidget {
  const _Problem(this.message, {this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileX, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
