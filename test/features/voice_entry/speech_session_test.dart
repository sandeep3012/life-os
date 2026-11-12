import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/voice_entry/data/speech_capture.dart';

/// Stands in for the phone's recogniser: each [listen] is one piece, ended
/// by [endPiece] the way Android ends one after a short pause.
class FakeRecognizer implements SpeechRecognizer {
  late void Function(String status) _onStatus;
  late void Function(String error) _onError;
  void Function(String words, {required bool isFinal})? _onResult;
  int listens = 0;
  bool stopped = false;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String words, {required bool isFinal}) onResult,
    required Duration listenFor,
    required Duration pauseFor,
    List<String> hints = const [],
  }) async {
    listens++;
    _onResult = onResult;
  }

  void partial(String words) => _onResult?.call(words, isFinal: false);

  /// The phone decides the speaker paused: a final result, then "done".
  void endPiece(String words) {
    _onResult?.call(words, isFinal: true);
    _onStatus(SpeechRecognizer.doneStatus);
  }

  void error(String code) => _onError(code);

  /// What Android's plugin sends for a continuous recogniser's pause: no
  /// final result, no "done", just "notListening".
  void stopsListening() => _onStatus(SpeechRecognizer.notListeningStatus);

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> cancel() async {}
}

class Heard {
  final updates = <(String, String)>[];
  String? done;

  void call(String settled, String pending, {required bool done}) {
    if (done) {
      this.done = settled;
    } else {
      updates.add((settled, pending));
    }
  }
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('SpeechTranscript', () {
    test('keeps finished pieces and adds the next words after them', () {
      final t = SpeechTranscript()
        ..hear('spent 250')
        ..settle('spent 250 on lunch');
      expect(t.settled, 'spent 250 on lunch');
      t.hear('from HDFC');
      expect(t.pending, 'from HDFC');
      expect(t.full, 'spent 250 on lunch from HDFC');
    });

    test('a fresh result without a final one keeps the last', () {
      final t = SpeechTranscript()
        ..hear('spent 250 on lunch at Subway')
        ..hear('with');
      expect(t.settled, 'spent 250 on lunch at Subway');
      expect(t.pending, 'with');
    });

    test("a continuous recogniser's pieces all add up (moto g64 log)", () {
      // The exact results a Moto g64 (Android 15, Google speech services)
      // sent for "spend 5000 … on shopping" with a pause in the middle. It
      // never sends a final result; each piece starts from "".
      final t = SpeechTranscript();
      for (final r in ['', '', '', 'spend', 'spend', 'spend 5000']) {
        t.hear(r);
      }
      expect(t.full, 'spend 5000');
      for (final r in ['spend 5000', '', '', ' on', ' on shopping']) {
        t.hear(r);
        // Never blanks what's already been said.
        expect(t.full, startsWith('spend 5000'));
      }
      expect(t.settled, 'spend 5000');
      expect(t.pending, 'on shopping');
      expect(t.full, 'spend 5000 on shopping');
    });

    test('a new piece without the empty result between still adds up', () {
      final t = SpeechTranscript()
        ..hear('spend 5000')
        ..hear(' on')
        ..hear(' on shopping');
      expect(t.full, 'spend 5000 on shopping');
    });

    test('revised words are not mistaken for a new piece', () {
      final t = SpeechTranscript()
        ..hear('spend two')
        ..hear('spent 250 on');
      expect(t.settled, isEmpty);
      expect(t.pending, 'spent 250 on');
    });

    test('a late final for a piece already kept is not repeated', () {
      final t = SpeechTranscript()
        ..hear('call mom')
        ..settlePending()
        ..settle('call mom');
      expect(t.full, 'call mom');
    });
  });

  group('SpeechSession', () {
    late FakeRecognizer recognizer;
    late SpeechSession session;
    late Heard heard;

    setUp(() {
      recognizer = FakeRecognizer();
      session = SpeechSession(
        recognizer,
        silence: const Duration(milliseconds: 300),
        limit: const Duration(seconds: 5),
      );
      heard = Heard();
    });

    test('a short pause carries on instead of losing the words', () async {
      await session.start(onText: heard.call);
      recognizer.partial('spent 250');
      expect(heard.updates.last, ('', 'spent 250'));

      recognizer.endPiece('spent 250 on lunch');
      await wait(200);
      expect(recognizer.listens, 2, reason: 'listening started again');
      expect(heard.done, isNull);

      recognizer.partial('from HDFC');
      expect(heard.updates.last, ('spent 250 on lunch', 'from HDFC'));
      recognizer.endPiece('from HDFC card');

      await wait(450);
      expect(heard.done, 'spent 250 on lunch from HDFC card');
    });

    test('Done delivers everything, pending words included', () async {
      await session.start(onText: heard.call);
      recognizer.endPiece('call mom');
      await wait(200);
      recognizer.partial('tomorrow at six');
      await session.stop();
      expect(recognizer.stopped, isTrue);
      await wait(900);
      expect(heard.done, 'call mom tomorrow at six');
    });

    test('silence with nothing said ends with nothing', () async {
      await session.start(onText: heard.call);
      await wait(400);
      expect(heard.done, '');
    });

    test(
      'continuous results with no final still end as one sentence',
      () async {
        await session.start(onText: heard.call);
        for (final r in [
          '',
          'spend',
          'spend 5000',
          '',
          ' on',
          ' on shopping',
        ]) {
          recognizer.partial(r);
        }
        expect(heard.updates.last, ('spend 5000', 'on shopping'));
        expect(recognizer.listens, 1, reason: 'one listen, never restarted');
        await wait(450);
        expect(heard.done, 'spend 5000 on shopping');
      },
    );

    test('"notListening" after a pause listens again, words kept', () async {
      await session.start(onText: heard.call);
      recognizer.partial('spend 5000');
      recognizer.stopsListening();
      await wait(200);
      expect(recognizer.listens, 2);
      expect(heard.done, isNull);
      recognizer.partial('on shopping');
      expect(heard.updates.last, ('spend 5000', 'on shopping'));
      await wait(450);
      expect(heard.done, 'spend 5000 on shopping');
    });

    test('a no-match after a pause just listens again', () async {
      await session.start(onText: heard.call);
      recognizer.partial('gym every');
      recognizer.error('error_no_match');
      await wait(200);
      expect(recognizer.listens, 2);
      recognizer.endPiece('Monday');
      await wait(450);
      expect(heard.done, 'gym every Monday');
    });

    test('a real error ends listening with what there is', () async {
      await session.start(onText: heard.call);
      recognizer.partial('lunch 200');
      recognizer.error('error_permission');
      expect(heard.done, 'lunch 200');
    });
  });
}
