import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../application/health_providers.dart';

/// Adds an exercise to a training session, or edits one when [initial] is set.
///
/// The scheme ("4×10") is free text on purpose — it's the plan as written in a
/// notebook, not arithmetic the app computes from. What actually happened is
/// logged per set instead.
class AddExerciseSheet extends ConsumerStatefulWidget {
  const AddExerciseSheet({
    super.key,
    required this.workoutDayId,
    required this.position,
    this.initial,
  });

  final String workoutDayId;
  final int position;
  final Exercise? initial;

  @override
  ConsumerState<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<AddExerciseSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _scheme = TextEditingController(
    text: widget.initial?.scheme ?? '3×10',
  );

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _scheme.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final controller = ref.read(healthControllerProvider);
    if (_isEditing) {
      await controller.updateExercise(
        id: widget.initial!.id,
        name: name,
        scheme: _scheme.text.trim(),
      );
    } else {
      await controller.addExercise(
        workoutDayId: widget.workoutDayId,
        name: name,
        scheme: _scheme.text.trim(),
        position: widget.position,
      );
    }
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return CompactEditorSheet(
      title: _isEditing ? 'Edit exercise' : 'Add an exercise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Exercise',
              hintText: 'Incline dumbbell press',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scheme,
            decoration: const InputDecoration(
              labelText: 'Target',
              hintText: '4×10',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add exercise'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddExerciseSheet(
  BuildContext context,
  WidgetRef ref, {
  required String workoutDayId,
  required int position,
  Exercise? initial,
}) async {
  final saved = await showCompactEditorSheet<String>(
    context: context,
    builder: (context) => AddExerciseSheet(
      workoutDayId: workoutDayId,
      position: position,
      initial: initial,
    ),
  );
  if (saved == null || !context.mounted) return;
  await showSaveFeedback(
    context,
    ref,
    title: initial == null ? 'Exercise saved' : 'Exercise updated',
    message: initial == null
        ? '“$saved” was added to the session.'
        : 'Changes to “$saved” were saved.',
  );
}
