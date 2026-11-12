import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why listening couldn't start or stopped early.
class SpeechCaptureException implements Exception {
  const SpeechCaptureException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What's been heard: [settled] words the recogniser has finished with, and
/// [pending] words it's still working out (they can still change).
typedef SpeechTextCallback =
    void Function(String settled, String pending, {required bool done});

/// The phone's own speech recognition, behind an interface so tests don't
/// need a microphone.
abstract class SpeechCapture {
  /// Starts listening. [onText] gets the words so far as they're
  /// recognised, then everything said with `done: true` (and nothing
  /// pending) once listening ends.
  Future<void> start({
    required SpeechTextCallback onText,
    List<String> hints = const [],
  });

  /// Stops and delivers everything said.
  Future<void> stop();

  /// Stops without delivering anything.
  Future<void> cancel();
}

/// Everything said in one go, across the pieces a recogniser splits it into.
///
/// Android's recogniser decides on its own that a sentence is over after a
/// second or two of silence and starts the next words from scratch; keeping
/// only its latest result lost everything said before the pause. Finished
/// pieces are kept here and the rest is added after them.
class SpeechTranscript {
  final _pieces = <String>[];
  String _pending = '';

  String get settled => _pieces.join(' ');
  String get pending => _pending;
  String get full => [settled, _pending].where((s) => s.isNotEmpty).join(' ');

  /// Words still being worked out.
  ///
  /// Google's recogniser on Android runs continuously and never sends a
  /// final result: after each pause it opens the next piece with an empty
  /// result, then sends the new words on their own, often with a leading
  /// space (" on", " on shopping"). Taking each result as the whole text
  /// wiped everything said before the pause, and the empty ones blanked the
  /// screen for a moment. So: an empty result keeps what was there as said;
  /// a result that clearly isn't a revision of the last one (it starts
  /// with a space, or suddenly shrinks, and doesn't begin like it) means a
  /// new piece, and the last one is kept first.
  void hear(String words) {
    final next = words.trim();
    final last = _pending;
    if (next.isEmpty) {
      settlePending();
      return;
    }
    if (last.isNotEmpty) {
      final revision = next.toLowerCase().startsWith(
        last.toLowerCase().split(' ').first,
      );
      final newPiece =
          words.startsWith(' ') || next.length < last.length ~/ 2;
      if (newPiece && !revision) _pieces.add(last);
    }
    _pending = next;
  }

  /// The recogniser has finished with these words.
  void settle(String words) {
    final done = words.trim().isEmpty ? _pending : words.trim();
    // A final result can arrive just after the piece was already kept (the
    // listen ended first); don't keep it twice.
    final repeat =
        _pieces.isNotEmpty && _pieces.last.toLowerCase() == done.toLowerCase();
    if (done.isNotEmpty && !repeat) _pieces.add(done);
    _pending = '';
  }

  /// Keeps whatever is pending as said — for stopping mid-word.
  void settlePending() {
    if (_pending.isNotEmpty) _pieces.add(_pending);
    _pending = '';
  }
}

/// One listen of the platform recogniser: what [SpeechSession] restarts
/// after each pause.
abstract class SpeechRecognizer {
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  /// Listens until the recogniser decides the speaker paused.
  Future<void> listen({
    required void Function(String words, {required bool isFinal}) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    List<String> hints = const [],
  });

  Future<void> stop();
  Future<void> cancel();

  /// Reported when a listen has ended.
  static const doneStatus = 'done';

  /// Also means a listen has ended. Android's plugin sends only this when a
  /// continuous recogniser pauses — its own "done" is held back while the
  /// latest result is a partial one, and continuous recognisers never send
  /// anything else.
  static const notListeningStatus = 'notListening';
}

/// Listening that survives pauses: it keeps everything said, starts the
/// recogniser again each time the phone ends a piece, and only finishes on
/// Done, after [silence] with nothing new heard, or at [limit].
class SpeechSession implements SpeechCapture {
  SpeechSession(
    this._recognizer, {
    this.silence = const Duration(seconds: 5),
    this.limit = const Duration(seconds: 60),
  });

  final SpeechRecognizer _recognizer;
  final Duration silence;
  final Duration limit;

  bool _ready = false;
  SpeechTextCallback? _onText;
  List<String> _hints = const [];
  var _transcript = SpeechTranscript();
  final _clock = Stopwatch();
  Duration _lastHeard = Duration.zero;
  Timer? _silenceTimer;
  Timer? _limitTimer;
  Timer? _stopTimer;
  bool _active = false;
  bool _stopping = false;
  bool _restarting = false;
  int _quickFailures = 0;

  /// Debug builds only: what happened and when, for reading the phone's log
  /// when a recogniser misbehaves.
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('voice: [${_clock.elapsedMilliseconds} ms] $message');
    }
  }

  @override
  Future<void> start({
    required SpeechTextCallback onText,
    List<String> hints = const [],
  }) async {
    _onText = onText;
    _hints = hints;
    _transcript = SpeechTranscript();
    _stopping = false;
    _quickFailures = 0;
    if (!_ready) {
      _ready = await _recognizer.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!_ready) {
        throw const SpeechCaptureException(
          'Speech recognition isn\'t available. Allow the microphone for '
          'LifeOS, and check the phone has a speech service (Google on '
          'Android).',
        );
      }
    }
    _active = true;
    _clock
      ..reset()
      ..start();
    _lastHeard = Duration.zero;
    _armSilence();
    _limitTimer?.cancel();
    _limitTimer = Timer(limit, () => _finish('time limit'));
    await _listen();
  }

  Future<void> _listen() async {
    if (!_active) return;
    final left = limit - _clock.elapsed;
    if (left <= Duration.zero) return _finish('time limit');
    await _recognizer.listen(
      onResult: _onResult,
      listenFor: left,
      pauseFor: silence,
      hints: _hints,
    );
  }

  void _onResult(String words, {required bool isFinal}) {
    if (!_active) return;
    if (words.trim().isNotEmpty) {
      _lastHeard = _clock.elapsed;
      _quickFailures = 0;
      _armSilence();
    }
    if (isFinal) {
      _transcript.settle(words);
      if (_stopping) return _finish('stopped by Done');
    } else {
      _transcript.hear(words);
    }
    _onText?.call(_transcript.settled, _transcript.pending, done: false);
  }

  void _onStatus(String status) {
    _log('status $status');
    if (!_active) return;
    if (status != SpeechRecognizer.doneStatus &&
        status != SpeechRecognizer.notListeningStatus) {
      return;
    }
    _pieceEnded();
  }

  void _onError(String error) {
    _log('error $error');
    if (!_active) return;
    // A pause with nothing new, or a recogniser still winding down: the
    // same as a piece ending. Anything else (no permission, no network for
    // the recogniser) ends listening with what there is.
    const pauses = {
      'error_no_match',
      'error_speech_timeout',
      'error_busy',
      'error_client',
    };
    if (pauses.contains(error)) {
      _pieceEnded(failed: true);
    } else {
      _finish('error $error');
    }
  }

  /// The recogniser stopped listening: carry on unless it's time to finish.
  void _pieceEnded({bool failed = false}) {
    if (_stopping) return _finish('stopped by Done');
    final quiet = _clock.elapsed - _lastHeard;
    if (quiet >= silence) return _finish('silence');
    if (_restarting) return;
    // Restarting straight after an error can fail again at once; give up
    // after a few in a row rather than spin.
    if (failed && ++_quickFailures > 5) return _finish('repeated errors');
    _transcript.settlePending();
    _restarting = true;
    _log('piece ended, listening again');
    Timer(const Duration(milliseconds: 150), () async {
      _restarting = false;
      try {
        await _listen();
      } on Object catch (e) {
        _finish('restart failed: $e');
      }
    });
  }

  void _armSilence() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silence, () => _finish('silence timer'));
  }

  void _finish([String reason = '']) {
    if (!_active) return;
    _log('finished: $reason');
    _active = false;
    _silenceTimer?.cancel();
    _limitTimer?.cancel();
    _stopTimer?.cancel();
    _clock.stop();
    unawaited(_recognizer.stop().catchError((_) {}));
    _transcript.settlePending();
    _onText?.call(_transcript.full, '', done: true);
  }

  @override
  Future<void> stop() async {
    if (!_active) return;
    _stopping = true;
    await _recognizer.stop();
    // Most recognisers send a final result after stop; some never do.
    _stopTimer?.cancel();
    _stopTimer = Timer(
      const Duration(milliseconds: 800),
      () => _finish('stopped by Done'),
    );
  }

  @override
  Future<void> cancel() async {
    if (_active) _log('cancelled');
    _active = false;
    _silenceTimer?.cancel();
    _limitTimer?.cancel();
    _stopTimer?.cancel();
    await _recognizer.cancel();
  }
}

/// The `speech_to_text` plugin as a [SpeechRecognizer].
class PluginSpeechRecognizer implements SpeechRecognizer {
  final _speech = SpeechToText();

  /// Indian English first — it copes with Hinglish ("250 ka lunch") and
  /// Indian names far better than US English — then whatever the phone
  /// uses.
  static const _preferredLocales = ['en_IN', 'en-IN'];
  String? _locale;
  bool _localeChecked = false;

  Future<String?> _pickLocale() async {
    if (_localeChecked) return _locale;
    _localeChecked = true;
    try {
      final available = await _speech.locales();
      for (final wanted in _preferredLocales) {
        for (final l in available) {
          if (l.localeId.toLowerCase() == wanted.toLowerCase()) {
            return _locale = l.localeId;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) => _speech.initialize(
    onStatus: onStatus,
    onError: (SpeechRecognitionError e) => onError(e.errorMsg),
    // The plugin's own log ("SpeechToTextPlugin" in logcat), debug only.
    debugLogging: kDebugMode,
  );

  @override
  Future<void> listen({
    required void Function(String words, {required bool isFinal}) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    List<String> hints = const [],
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        if (kDebugMode) {
          debugPrint(
            'voice: ${r.finalResult ? 'final' : 'partial'} '
            '"${r.recognizedWords}"',
          );
        }
        onResult(r.recognizedWords, isFinal: r.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: await _pickLocale(),
        partialResults: true,
        // SpeechSession decides what an error means.
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        listenFor: listenFor,
        pauseFor: pauseFor,
        contextualPhrases: hints.take(100).toList(),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

final speechCaptureProvider = Provider<SpeechCapture>(
  (ref) => SpeechSession(PluginSpeechRecognizer()),
);
