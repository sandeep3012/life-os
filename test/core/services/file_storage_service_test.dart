import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_storage_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('importFile copies into a managed documents subfolder under a generated name', () async {
    final source = File('${tempDir.path}/source.txt')..writeAsStringSync('hello');
    final storage = FileStorageService();

    final stored = await storage.importFile(source, originalName: 'notes.txt');

    expect(stored.relativePath, startsWith('documents${p.separator}'));
    expect(stored.relativePath, endsWith('.txt'));
    expect(stored.mimeType, 'text/plain');
    expect(stored.thumbnailRelativePath, isNull);
    expect(stored.sizeBytes, 5);

    final dest = await storage.absoluteFile(stored.relativePath);
    expect(await dest.exists(), isTrue);
    expect(await dest.readAsString(), 'hello');
  });

  test('deleteFile removes the stored file', () async {
    final source = File('${tempDir.path}/source.txt')..writeAsStringSync('hello');
    final storage = FileStorageService();

    final stored = await storage.importFile(source, originalName: 'notes.txt');
    await storage.deleteFile(stored.relativePath);

    final dest = await storage.absoluteFile(stored.relativePath);
    expect(await dest.exists(), isFalse);
  });
}
