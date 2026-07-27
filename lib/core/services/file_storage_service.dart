import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};

const _mimeByExtension = {
  '.pdf': 'application/pdf',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.heic': 'image/heic',
  '.webp': 'image/webp',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.txt': 'text/plain',
};

class StoredFile {
  const StoredFile({
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    this.thumbnailRelativePath,
  });

  final String relativePath;
  final String? thumbnailRelativePath;
  final String mimeType;
  final int sizeBytes;
}

/// Owns where document bytes actually live on-device: features only ever
/// call this service (never `path_provider` directly), so the backing
/// storage can later move to cloud sync without touching feature code.
/// Only a relative path is ever persisted in the [Documents] table — the
/// app-sandbox absolute path can change between installs/devices.
class FileStorageService {
  static const _subdir = 'documents';

  Future<Directory> _documentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _mimeFor(String fileName) {
    return _mimeByExtension[p.extension(fileName).toLowerCase()] ??
        'application/octet-stream';
  }

  /// Copies [source] into the app's managed documents folder under a
  /// generated UUID filename (never the original name — it isn't trusted),
  /// generating a compressed thumbnail for image files.
  Future<StoredFile> importFile(File source, {required String originalName}) async {
    final dir = await _documentsDir();
    final ext = p.extension(originalName).toLowerCase();
    final id = const Uuid().v4();
    final destPath = p.join(dir.path, '$id$ext');
    final dest = await source.copy(destPath);

    String? thumbRelativePath;
    if (_imageExtensions.contains(ext)) {
      final thumbPath = p.join(dir.path, '${id}_thumb.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        dest.path,
        thumbPath,
        minWidth: 300,
        minHeight: 300,
        quality: 70,
      );
      if (result != null) {
        thumbRelativePath = p.join(_subdir, '${id}_thumb.jpg');
      }
    }

    return StoredFile(
      relativePath: p.join(_subdir, '$id$ext'),
      thumbnailRelativePath: thumbRelativePath,
      mimeType: _mimeFor(originalName),
      sizeBytes: await dest.length(),
    );
  }

  Future<File> absoluteFile(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, relativePath));
  }

  Future<void> deleteFile(String relativePath, {String? thumbnailRelativePath}) async {
    final file = await absoluteFile(relativePath);
    if (await file.exists()) await file.delete();
    if (thumbnailRelativePath != null) {
      final thumb = await absoluteFile(thumbnailRelativePath);
      if (await thumb.exists()) await thumb.delete();
    }
  }
}

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});
