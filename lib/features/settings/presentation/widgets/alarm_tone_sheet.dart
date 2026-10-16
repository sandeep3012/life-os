import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/reminders/alarm_tone.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';

/// Settings → Alarm tone: the three tones, each with a play button to hear
/// it first. Choosing one returns it; the sheet stops any preview on close.
Future<AlarmTone?> showAlarmToneSheet(
  BuildContext context, {
  required AlarmTone current,
}) => showCompactEditorSheet<AlarmTone>(
  context: context,
  builder: (_) => _AlarmToneSheet(current: current),
);

class _AlarmToneSheet extends StatefulWidget {
  const _AlarmToneSheet({required this.current});

  final AlarmTone current;

  @override
  State<_AlarmToneSheet> createState() => _AlarmToneSheetState();
}

class _AlarmToneSheetState extends State<_AlarmToneSheet> {
  /// Created on the first preview, not with the sheet: most people choose
  /// without listening, and there's no reason to start audio for them.
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  late AlarmTone _selected = widget.current;
  AlarmTone? _playing;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _completion = player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    return _player = player;
  }

  @override
  void dispose() {
    _completion?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AlarmTone tone) async {
    try {
      final player = _ensurePlayer();
      if (_playing == tone) {
        await player.stop();
        if (mounted) setState(() => _playing = null);
        return;
      }
      await player.stop();
      if (mounted) setState(() => _playing = tone);
      await player.play(AssetSource(tone.previewAsset));
    } catch (_) {
      // No audio output available; the choice still works without a preview.
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CompactEditorSheet(
      title: 'Alarm tone',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What reminders set to ring as an alarm play. Normal '
            'notifications keep their own sounds.',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final tone in AlarmTone.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _selected == tone
                    ? scheme.primary.withValues(alpha: 0.10)
                    : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _selected == tone
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: _selected == tone ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _selected = tone),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Icon(
                          _selected == tone
                              ? LucideIcons.circleCheck
                              : LucideIcons.circle,
                          size: 20,
                          color: _selected == tone
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tone.label,
                                style: const TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                tone.description,
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _playing == tone
                              ? 'Stop ${tone.label}'
                              : 'Play ${tone.label}',
                          onPressed: () => _togglePreview(tone),
                          icon: Icon(
                            _playing == tone
                                ? LucideIcons.square
                                : LucideIcons.play,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Use this tone'),
            ),
          ),
        ],
      ),
    );
  }
}
