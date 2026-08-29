import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/voice_model_service.dart';
import '../../../../core/services/voice_recognition_service.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../domain/voice_command.dart';
import '../../domain/voice_command_parser.dart';

class VoiceCommandsScreen extends ConsumerStatefulWidget {
  const VoiceCommandsScreen({super.key});

  @override
  ConsumerState<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}
class _VoiceCommandsScreenState extends ConsumerState<VoiceCommandsScreen> {
  bool _listening = false;
  @override
  Widget build(BuildContext context) {
    final service = ref.read(voiceModelServiceProvider);
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Voice commands')),
      body: FutureBuilder<bool>(
        future: service.isInstalled,
        builder: (context, snapshot) {
          final ready = snapshot.data ?? false;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(ready ? 'Tap to speak' : 'Download the English voice model first', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(ready ? 'Your voice stays on this device.' : 'You can manage the model in Settings → Voice commands.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: ready && !_listening ? _record : null,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Start voice command'),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _record() async {
    setState(() => _listening = true);
    try {
      final text = await ref.read(voiceRecognitionServiceProvider).recordCommand();
      if (!mounted) return;
      final command = parseVoiceCommand(text);
      await showModalBottomSheet<void>(context: context, builder: (context) => Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Heard', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(text.isEmpty ? 'No speech recognised.' : text),
          const SizedBox(height: 16), Text(_commandSummary(command)), const SizedBox(height: 16),
          FilledButton(onPressed: command is UnrecognisedVoiceCommand ? null : () async { await _apply(command); if (context.mounted) Navigator.pop(context); }, child: const Text('Confirm')),
        ]),
      ));
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
    finally { if (mounted) setState(() => _listening = false); }
  }

  String _commandSummary(VoiceCommand command) => switch (command) { CreateTaskVoiceCommand(:final title) => 'Create task: $title', CompleteHabitVoiceCommand(:final habitName) => 'Complete habit: $habitName', _ => 'I could not understand that command yet.' };
  Future<void> _apply(VoiceCommand command) async { switch (command) { case CreateTaskVoiceCommand(:final title): await ref.read(tasksControllerProvider).addTask(title: title); case CompleteHabitVoiceCommand(:final habitName): final habit = ref.read(habitsListProvider).value?.where((h) => h.name.toLowerCase() == habitName.toLowerCase()).firstOrNull; if (habit == null) throw StateError('No matching habit found.'); await ref.read(habitsControllerProvider).toggleToday(habit, true); case UnrecognisedVoiceCommand(): } }
}
