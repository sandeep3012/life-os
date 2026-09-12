import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/health_providers.dart';

/// Logs what was actually lifted: weight and reps, one set at a time, with the
/// day's sets listed underneath so the next set can be matched or beaten.
///
/// Both figures use steppers rather than a keyboard — the kit's stepper control —
/// because logging happens mid-set with one hand. Weight steps in 2.5 kg, the
/// smallest plate pair on most bars.
class LogSetSheet extends ConsumerStatefulWidget {
  const LogSetSheet({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends ConsumerState<LogSetSheet> {
  double _weightKg = 20;
  int _reps = 10;
  bool _seeded = false;

  static const _weightStep = 2.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final session = ref.watch(exerciseSessionProvider(widget.exercise.id));

    // Start from the last set logged today, so a second set doesn't begin from
    // the default every time.
    if (!_seeded && session.sets.isNotEmpty) {
      final last = session.sets.last;
      _weightKg = ExerciseSession.kg(last.weightGrams);
      _reps = last.reps;
      _seeded = true;
    }

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
          child: SingleChildScrollView(
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
                  widget.exercise.name,
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (widget.exercise.scheme.isNotEmpty)
                  Text(
                    'Target ${widget.exercise.scheme}',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12.5,
                      color: colors.text3,
                    ),
                  ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Stepper(
                        label: 'Weight',
                        value: ExerciseSession.formatKg((_weightKg * 1000).round()),
                        onDecrement: _weightKg <= 0
                            ? null
                            : () => setState(() {
                                  _weightKg =
                                      (_weightKg - _weightStep).clamp(0, 500);
                                }),
                        onIncrement: () => setState(() {
                          _weightKg = (_weightKg + _weightStep).clamp(0, 500);
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stepper(
                        label: 'Reps',
                        value: '$_reps',
                        onDecrement: _reps <= 1
                            ? null
                            : () => setState(() => _reps--),
                        onIncrement: () => setState(() => _reps++),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(healthControllerProvider).logSet(
                      exerciseId: widget.exercise.id,
                      reps: _reps,
                      weightKg: _weightKg,
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text('Log set ${session.setCount + 1}'),
                ),

                if (session.sets.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Today's sets",
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${session.setCount} sets · '
                        '${ExerciseSession.formatKg(session.volumeGrams)} volume',
                        style: TextStyle(
                          fontFamily: AppFonts.numeric,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.text3,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final set in session.sets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _SetRow(
                        set: set,
                        onDelete: () => ref
                            .read(healthControllerProvider)
                            .deleteSet(set.id),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kit §4: a 44px `−` and `+` flanking a centred tabular value.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.text3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StepButton(
                icon: LucideIcons.minus,
                onTap: onDecrement,
                filled: false,
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.numeric,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
              _StepButton(
                icon: LucideIcons.plus,
                onTap: onIncrement,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.selection,
      small: true,
      semanticLabel: filled ? 'Increase' : 'Decrease',
      child: Container(
        width: AppSpacing.minTouchTarget,
        height: AppSpacing.minTouchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? scheme.primary : scheme.surfaceContainer,
          border: filled ? null : Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled
              ? scheme.onPrimary
              : enabled
                  ? scheme.onSurface
                  : scheme.outline,
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.onDelete});

  final ExerciseSetLog set;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        children: [
          Text(
            'Set ${set.setNumber}',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.text3,
            ),
          ),
          const Spacer(),
          Text(
            '${ExerciseSession.formatKg(set.weightGrams)} × ${set.reps}',
            style: TextStyle(
              fontFamily: AppFonts.numeric,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontFeatures: AppFonts.tabular,
            ),
          ),
          const SizedBox(width: 6),
          Tappable(
            onTap: onDelete,
            haptic: TapHaptic.selection,
            small: true,
            semanticLabel: 'Remove set ${set.setNumber}',
            enforceMinTouchTarget: true,
            child: Icon(LucideIcons.trash2, size: 15, color: colors.critical),
          ),
        ],
      ),
    );
  }
}

Future<void> showLogSetSheet(BuildContext context, Exercise exercise) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => LogSetSheet(exercise: exercise),
  );
}
