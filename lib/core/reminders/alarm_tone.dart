/// The sound alarm-mode reminders ring with, chosen in Settings → Alarm
/// tone. Each names a sound shipped three ways: OGG in Android's res/raw,
/// WAV in the iOS bundle, and an MP3 asset for the in-app preview.
enum AlarmTone {
  gentle('alarm_gentle', 'Gentle', 'Soft and rising — wake-ups, habits'),
  tapTapBell(
    'alarm_important_knock',
    'Tap-tap-bell',
    'Firm and clear — bills, must-dos',
  ),
  marimba('alarm_important_marimba', 'Marimba call', 'Bright and insistent');

  const AlarmTone(this.sound, this.label, this.description);

  /// The sound's file name without extension, on every platform.
  final String sound;
  final String label;
  final String description;

  String get previewAsset => 'sounds/$sound.mp3';

  static AlarmTone fromStorage(String? value) => AlarmTone.values.firstWhere(
    (t) => t.name == value,
    orElse: () => AlarmTone.gentle,
  );
}
