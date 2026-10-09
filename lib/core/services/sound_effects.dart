import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';

/// The moments that get a sound.
enum SoundEffect {
  taskDone('task_done_wood'),
  habitStreak('habit_streak'),
  goalReached('goal_reached'),
  budgetAlert('budget_alert');

  const SoundEffect(this.sound);

  /// The file name in `assets/sounds/`, without `.mp3`.
  final String sound;
}

/// Plays a sound file. The real one uses audioplayers; tests record calls.
abstract class SoundPlayer {
  Future<void> play(String asset);
}

class _AudioSoundPlayer implements SoundPlayer {
  final _players = <String, AudioPlayer>{};

  /// A short effect alongside whatever else is playing — music keeps going —
  /// and silent when the phone is on silent.
  static final _context = AudioContextConfig(
    respectSilence: true,
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  @override
  Future<void> play(String asset) async {
    // Guarded as a zone, not just a try: a player also fails in futures and
    // streams of its own (no audio plugin in widget tests, an audio session
    // refused), and those must never surface as app errors.
    await runZonedGuarded(() async {
      final player = _players.putIfAbsent(asset, AudioPlayer.new);
      await player.setAudioContext(_context);
      await player.stop();
      await player.play(AssetSource(asset));
    }, (_, _) {});
  }
}

final soundPlayerProvider = Provider<SoundPlayer>((ref) => _AudioSoundPlayer());

/// The app's sound effects, behind Settings → Sounds. Fire-and-forget: a
/// sound never delays or breaks the action it accompanies.
class SoundEffects {
  SoundEffects(this._ref);

  final Ref _ref;

  void play(SoundEffect effect) {
    if (!_ref.read(settingsProvider).soundEffectsEnabled) return;
    _ref
        .read(soundPlayerProvider)
        .play('sounds/${effect.sound}.mp3')
        .catchError((Object _) {});
  }
}

final soundEffectsProvider = Provider<SoundEffects>(SoundEffects.new);
