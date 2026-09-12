import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../application/health_providers.dart';

/// Adds an exercise to a training session.
///
/// The scheme ("4×10") is free text on purpose — it's the plan as written in a
/// notebook, not arithmetic the app computes from. What actually happened is
/// logged per set instead.
class AddExerciseSheet extends ConsumerStatefulWidget {
  const AddExerciseSheet({
    super.key,
    required this.workoutDayId,
    required this.position,
  });

  final String workoutDayId;
  final int position;

  @override
  ConsumerState<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<AddExerciseSheet> {
  final _name = TextEditingController();
  final _scheme = TextEditingController(text: '3×10');

  @override
  void dispose() {
    _name.dispose();
    _scheme.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(healthControllerProvider).addExercise(
      workoutDayId: widget.workoutDayId,
      name: name,
      scheme: _scheme.text.trim(),
      position: widget.position,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add an exercise',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  autofocus: true,
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
                FilledButton(
                  onPressed: _save,
                  child: const Text('Add exercise'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAddExerciseSheet(
  BuildContext context, {
  required String workoutDayId,
  required int position,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => AddExerciseSheet(
      workoutDayId: workoutDayId,
      position: position,
    ),
  );
}
