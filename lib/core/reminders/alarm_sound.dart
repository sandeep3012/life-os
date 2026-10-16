import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm_tone.dart';

/// The alarm's sound while its ringing screen is up. The notification's own
/// sound stops the moment the notification is opened, so the screen rings
/// it itself — on the alarm audio stream, like the notification did, so
/// silent mode doesn't mute it.
abstract class AlarmSound {
  Future<void> start(AlarmTone tone);
  Future<void> stop();
}

class _PlayerAlarmSound implements AlarmSound {
  AudioPlayer? _player;
  Timer? _limit;

  /// A phone's own alarm stops by itself after a while; so does this.
  static const _maxRinging = Duration(minutes: 10);

  @override
  Future<void> start(AlarmTone tone) async {
    try {
      await stop();
      final player = _player = AudioPlayer();
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(tone.previewAsset));
      _limit = Timer(_maxRinging, stop);
    } catch (_) {
      // No audio output: the screen still shows, and the buttons work.
    }
  }

  @override
  Future<void> stop() async {
    _limit?.cancel();
    _limit = null;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }
}

final alarmSoundProvider = Provider<AlarmSound>((ref) {
  final sound = _PlayerAlarmSound();
  ref.onDispose(sound.stop);
  return sound;
});
