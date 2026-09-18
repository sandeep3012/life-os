import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/health_providers.dart';
import '../../../../core/widgets/dashed_action_button.dart';
import '../../../../core/widgets/initial_well.dart';
import '../widgets/add_exercise_sheet.dart';
import '../widgets/log_set_sheet.dart';
import '../widgets/medication_editor_sheet.dart';
import '../widgets/workout_plan_sheet.dart';

/// The comp's Health screen: a Medication / Gym tab rail, then either the
/// dose-tracking view (gradient "doses today" hero, time-grouped medication
/// rows, a refill warning) or the day's training block.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

enum _HealthTab { medication, gym }

class _HealthScreenState extends ConsumerState<HealthScreen> {
  _HealthTab _tab = _HealthTab.medication;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Health',
                  centerIsTitle: true,
                  showTrailing: false,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            AppTabRail<_HealthTab>(
              value: _tab,
              labels: const {
                _HealthTab.medication: 'Medication',
                _HealthTab.gym: 'Gym',
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            if (_tab == _HealthTab.medication)
              const _MedicationView()
            else
              const _GymView(),
          ],
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
              begin: 0.02,
              end: 0.0,
              duration: AppMotion.screenEnter,
              curve: AppMotion.standard,
            ),
      ),
    );
  }
}

class _MedicationView extends ConsumerWidget {
  const _MedicationView();

  static const _slotLabels = {
    'am': ('Morning', 'Before noon'),
    'pm': ('Afternoon', 'After lunch'),
    'night': ('Night', 'Before bed'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final doses = ref.watch(todayDosesProvider);
    final grouped = ref.watch(dosesBySlotProvider);
    final lowStock = ref.watch(lowStockMedicationProvider);

    final taken = doses.where((d) => d.taken).length;
    final total = doses.length;
    final next = doses.where((d) => !d.taken).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        _DosesHero(
          taken: taken,
          total: total,
          nextLabel: total == 0
              ? 'No medication scheduled today.'
              : next.isEmpty
                  ? 'All doses logged. Nicely done.'
                  : 'Next up: ${next.first.medication.name}',
        ),

        for (final entry in grouped.entries) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  LucideIcons.clock,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                _slotLabels[entry.key]?.$1 ?? entry.key,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _slotLabels[entry.key]?.$2 ?? '',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  color: colors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final dose in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _DoseRow(dose: dose),
            ),
        ],

        if (lowStock != null) ...[
          const SizedBox(height: 18),
          _RefillBanner(medication: lowStock),
        ],

        const SizedBox(height: 14),
        Tappable(
          haptic: TapHaptic.light,
          semanticLabel: 'Add a medication',
          onTap: () => showMedicationEditorSheet(context),
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 15),
            radius: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, size: 17, color: colors.accentInk),
                const SizedBox(width: 8),
                Text(
                  'Add a medication',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.accentInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Comp: a radius-24 gradient card — `DOSES TODAY` over `n of m taken`, a
/// progress track, and a line naming what's next.
class _DosesHero extends StatelessWidget {
  const _DosesHero({
    required this.taken,
    required this.total,
    required this.nextLabel,
  });

  final int taken;
  final int total;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onHero = Theme.of(context).colorScheme.onPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -0.866),
            end: const Alignment(0.5, 0.866),
            colors: [colors.heroA, colors.heroB],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.heroVeil,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(
                    'Doses today',
                    color: onHero.withValues(alpha: 0.92),
                    letterSpacing: 1.2,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$taken',
                        style: TextStyle(
                          fontFamily: AppFonts.serif,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: onHero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'of $total taken',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: onHero.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : taken / total,
                      minHeight: 6,
                      backgroundColor: colors.heroTrack,
                      valueColor: AlwaysStoppedAnimation<Color>(onHero),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    nextLabel,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12.5,
                      color: onHero.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: a radius-18 row — 42px pill well, name with a frequency chip and note,
/// remaining count, then a 26px check box. The whole row toggles.
class _DoseRow extends ConsumerWidget {
  const _DoseRow({required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final med = dose.medication;
    final accent = Color(int.parse(med.colorHex.replaceFirst('#', '0xFF')));
    final low = med.stockLeft != null && med.stockLeft! <= 7;

    return Tappable(
      haptic: TapHaptic.selection,
      semanticLabel: med.name,
      selected: dose.taken,
      onTap: () =>
          ref.read(healthControllerProvider).toggleDose(med, !dose.taken),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(
            color: dose.taken ? scheme.secondary : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(LucideIcons.pill, size: 20, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      decoration:
                          dose.taken ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dose.frequencyLabel,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          med.dosageNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12,
                            color: colors.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (med.stockLeft != null) ...[
              const SizedBox(width: 8),
              Text(
                '${med.stockLeft} left',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: low ? colors.warning : colors.text3,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dose.taken ? scheme.secondary : Colors.transparent,
                border: Border.all(
                  color: dose.taken ? scheme.secondary : scheme.outline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: dose.taken
                  ? Icon(LucideIcons.check, size: 15, color: scheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: the amber refill warning card.
class _RefillBanner extends StatelessWidget {
  const _RefillBanner({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final days = medication.stockLeft ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.13),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.triangleAlert, size: 17, color: colors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medication.name} runs out in $days '
                  '${days == 1 ? 'dose' : 'doses'}',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Order a refill before you run out.',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GymView extends ConsumerWidget {
  const _GymView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final workout = ref.watch(todayWorkoutProvider);

    final plan = ref.watch(weeklyPlanProvider);

    if (workout == null) {
      return Column(
        children: [
          const SizedBox(height: 32),
          Icon(LucideIcons.dumbbell, size: 34, color: colors.text3),
          const SizedBox(height: 12),
          Text(
            plan.isEmpty
                ? 'No training plan yet.'
                : 'Nothing scheduled for today.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.isEmpty
                ? 'Build a weekly plan and it shows up on the day.'
                : 'Your next session appears here on its day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          DashedActionButton(
            label: 'Add a training session',
            onTap: () => showWorkoutPlanSheet(context),
          ),
          if (plan.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Weekly plan'),
            const SizedBox(height: 11),
            _WeeklyPlanList(plan: plan),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Overline(workout.day.label, color: colors.text3)),
                  Tappable(
                    haptic: TapHaptic.light,
                    semanticLabel: 'Edit session',
                    enforceMinTouchTarget: true,
                    onTap: () =>
                        showWorkoutPlanSheet(context, initial: workout.day),
                    child: Icon(
                      LucideIcons.pencil,
                      size: 16,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                workout.day.focus.isEmpty ? workout.day.label : workout.day.focus,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: workout.progress,
                  minHeight: 6,
                  backgroundColor: scheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${workout.doneCount} of ${workout.exercises.length} exercises · '
                '${(workout.progress * 100).round()}% complete',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Exercises'),
        const SizedBox(height: 11),
        for (final exercise in workout.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _ExerciseRow(
              exercise: exercise,
              done: workout.completedIds.contains(exercise.id),
            ),
          ),
        const SizedBox(height: 2),
        DashedActionButton(
          label: 'Add an exercise',
          onTap: () => showAddExerciseSheet(
            context,
            workoutDayId: workout.day.id,
            position: workout.exercises.length,
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Weekly plan'),
        const SizedBox(height: 11),
        _WeeklyPlanList(plan: plan),
        const SizedBox(height: 10),
        DashedActionButton(
          label: 'Add a training session',
          onTap: () => showWorkoutPlanSheet(context),
        ),
      ],
    );
  }
}

/// The plan at a glance: one row per weekday that has a session, so a recurring
/// session shows up on each day it repeats on.
class _WeeklyPlanList extends ConsumerWidget {
  const _WeeklyPlanList({required this.plan});

  final Map<int, List<WorkoutDay>> plan;

  static const _names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final today = DateTime.now().weekday;

    return Column(
      children: [
        for (var day = 1; day <= 7; day++)
          if (plan[day] != null)
            for (final session in plan[day]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Tappable(
                  haptic: TapHaptic.light,
                  semanticLabel: '${_names[day - 1]}: ${session.label}',
                  onTap: () => showWorkoutPlanSheet(context, initial: session),
                  child: SurfaceCard.row(
                    child: Row(
                      children: [
                        InitialWell(
                          color: day == today ? scheme.secondary : colors.text3,
                          size: 38,
                          radius: 12,
                          label: _names[day - 1].substring(0, 2),
                          fontSize: 12,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                '${_names[day - 1]} · '
                                '${_time(session.startMinute)}–${_time(session.endMinute)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 12,
                                  color: colors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${ref.watch(exercisesForDayProvider(session.id)).length}',
                          style: TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: colors.text3,
                            fontFeatures: AppFonts.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  static String _time(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${m.toString().padLeft(2, '0')} $suffix';
  }
}

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({required this.exercise, required this.done});

  final Exercise exercise;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final session = ref.watch(exerciseSessionProvider(exercise.id));

    return Tappable(
      haptic: TapHaptic.selection,
      semanticLabel: exercise.name,
      selected: done,
      onLongPress: () =>
          ref.read(healthControllerProvider).deleteExercise(exercise.id),
      onTap: () =>
          ref.read(healthControllerProvider).toggleExercise(exercise, !done),
      child: SurfaceCard.row(
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? scheme.secondary : Colors.transparent,
                border: Border.all(
                  color: done ? scheme.secondary : scheme.outline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: done
                  ? Icon(LucideIcons.check, size: 15, color: scheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.setCount == 0
                        ? (exercise.scheme.isEmpty
                            ? 'No sets logged'
                            : 'Target ${exercise.scheme} · no sets logged')
                        : '${session.setCount} sets · '
                            'top ${ExerciseSession.formatKg(session.topWeightGrams)} · '
                            '${session.totalReps} reps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11.5,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tappable(
              haptic: TapHaptic.light,
              semanticLabel: 'Log a set for ${exercise.name}',
              enforceMinTouchTarget: true,
              onTap: () => showLogSetSheet(context, exercise),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Text(
                  'Log set',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.accentInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
