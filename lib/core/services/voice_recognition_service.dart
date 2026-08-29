import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'voice_model_service.dart';

class VoiceRecognitionService {
  VoiceRecognitionService(this._models);

  final VoiceModelService _models;

  Future<String> recordCommand() async {
    if (!await _models.isValid) {
      throw StateError(
        'The English voice model is missing or incomplete. '
        'Remove it and download it again.',
      );
    }

    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      await recorder.dispose();
      throw StateError('Microphone permission was not granted.');
    }

    final path = await _models.modelPath;
    sherpa.initBindings();
    final recognizer = sherpa.OnlineRecognizer(
      sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$path/encoder-epoch-99-avg-1.int8.onnx',
            decoder: '$path/decoder-epoch-99-avg-1.int8.onnx',
            joiner: '$path/joiner-epoch-99-avg-1.int8.onnx',
          ),
          tokens: '$path/tokens.txt',
          // Let sherpa-onnx inspect the model metadata. This model predates
          // Zipformer2 and crashes natively if that loader is forced.
          modelType: '',
          debug: false,
        ),
        // Greedy search is fast, but it is noticeably less accurate for short
        // commands. Keep several likely transcriptions alive before choosing.
        decodingMethod: 'modified_beam_search',
        maxActivePaths: 4,
      ),
    );
    final stream = recognizer.createStream();
    try {
      final audio = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      await for (final chunk in audio) {
        final samples = Float32List(chunk.length ~/ 2);
        final bytes = ByteData.sublistView(chunk);
        for (var i = 0; i < samples.length; i++) {
          samples[i] = bytes.getInt16(i * 2, Endian.little) / 32768;
        }
        stream.acceptWaveform(samples: samples, sampleRate: 16000);
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        if (recognizer.isEndpoint(stream)) break;
      }

      // Streaming models need a small amount of trailing silence to emit the
      // final word. Without it, short command endings are often lost.
      stream.acceptWaveform(
        samples: Float32List(6400),
        sampleRate: 16000,
      );
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      stream.inputFinished();
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      return recognizer.getResult(stream).text.trim();
    } finally {
      try {
        await recorder.stop();
        await recorder.dispose();
      } finally {
        stream.free();
        recognizer.free();
      }
    }
  }
}

final voiceRecognitionServiceProvider = Provider<VoiceRecognitionService>(
  (ref) => VoiceRecognitionService(ref.watch(voiceModelServiceProvider)),
);
