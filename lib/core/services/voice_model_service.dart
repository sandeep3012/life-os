import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads the optional English model outside the app bundle.
class VoiceModelService {
  static const downloadUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2';
  Future<Directory> get _dir async => Directory(p.join((await getApplicationSupportDirectory()).path, 'voice-model-en'));
  final downloadProgress = ValueNotifier<double?>(null);
  final preparingModel = ValueNotifier(false);
  Future<bool> get isInstalled async => (await _dir).exists();
  Future<String> get modelPath async => (await _dir).path;

  Future<bool> get isValid async {
    final dir = await _dir;
    if (!await dir.exists()) return false;
    const requiredFiles = [
      'encoder-epoch-99-avg-1.int8.onnx',
      'decoder-epoch-99-avg-1.int8.onnx',
      'joiner-epoch-99-avg-1.int8.onnx',
      'tokens.txt',
    ];
    for (final name in requiredFiles) {
      final file = File(p.join(dir.path, name));
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }
  Future<void> remove() async { final dir = await _dir; if (await dir.exists()) await dir.delete(recursive: true); }
  Future<void> download() async {
    final dir = await _dir; final temp = Directory('${dir.path}.staging');
    if (await temp.exists()) await temp.delete(recursive: true); await temp.create(recursive: true);
    final archive = File(p.join(temp.path, 'model.tar.bz2')); final client = HttpClient();
    try { final response = await (await client.getUrl(Uri.parse(downloadUrl))).close();
      if (response.statusCode != HttpStatus.ok) throw HttpException('Could not download the English voice model.');
      final sink = archive.openWrite();
      var received = 0;
      final total = response.contentLength;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) downloadProgress.value = received / total;
      }
      await sink.close();
      downloadProgress.value = null;
      preparingModel.value = true;
      await Isolate.run(() => extractFileToDisk(archive.path, temp.path));
      final extracted = Directory(p.join(temp.path, 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17'));
      if (!await extracted.exists()) throw const FileSystemException('Voice model archive was invalid.');
      if (await dir.exists()) await dir.delete(recursive: true); await extracted.rename(dir.path);
    } finally { downloadProgress.value = null; preparingModel.value = false; client.close(force: true); if (await temp.exists()) await temp.delete(recursive: true); }
  }
}
final voiceModelServiceProvider = Provider<VoiceModelService>((ref) => VoiceModelService());
