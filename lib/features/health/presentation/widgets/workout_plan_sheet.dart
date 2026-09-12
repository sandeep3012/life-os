import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/health_providers.dart';

/// Creates or edits a training session in the weekly plan.
///
/// When creating, the weekday picker is multi-select: the same session is added
/// to every selected day, which is how "repeats on Mon/Wed/Fri" is expressed —
/// one row per weekday rather than a recurrence rule, so the daily lookup stays
/// an equality check. Editing touches only the day you opened.
class WorkoutPlanSheet extends ConsumerStatefulWidget {
  const WorkoutPlanSheet({super.key, this.initial});

  final WorkoutDay? initial;

  @override
  ConsumerState<WorkoutPlanSheet> createState() => _WorkoutPlanSheetState();
}

class _WorkoutPlanSheetState extends ConsumerState<WorkoutPlanSheet> {
  late final TextEditingController _label;
  late final TextEditingController _focus;
  late Set<int> _weekdays;
  late TimeOfDay _start;
  late TimeOfDay _end;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _label = TextEditingController(text: d?.label ?? '');
    _focus = TextEditingController(text: d?.focus ?? '');
    _weekdays = {d?.weekday ?? DateTime.now().weekday};
    _start = _fromMinutes(d?.startMinute ?? 420);
    _end = _fromMinutes(d?.endMinute ?? 480);
  }

  @override
  void dispose() {
    _label.dispose();
    _focus.dispose();
    super.dispose();
  }

  static TimeOfDay _fromMinutes(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60);

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep the window valid rather than silently storing end <= start.
        if (_toMinutes(_end) <= _toMinutes(picked)) {
          _end = _fromMinutes(_toMinutes(picked) + 60);
        }
      } else if (_toMinutes(picked) > _toMinutes(_start)) {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty || _weekdays.isEmpty) return;

    final controller = ref.read(healthControllerProvider);
    if (_isEdit) {
      await controller.updateWorkoutDay(
        id: widget.initial!.id,
        label: label,
        focus: _focus.text.trim(),
        startMinute: _toMinutes(_start),
        endMinute: _toMinutes(_end),
      );
    } else {
      await controller.addWeeklyPlan(
        weekdays: _weekdays.toList()..sort(),
        label: label,
        focus: _focus.text.trim(),
        startMinute: _toMinutes(_start),
        endMinute: _toMinutes(_end),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

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
                  _isEdit ? 'Edit session' : 'New training session',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _label,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Session',
                    hintText: 'Push Day',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Focus',
                    hintText: 'Chest & Triceps',
                  ),
                ),

                const SizedBox(height: 16),
                _Label(_isEdit ? 'Day' : 'Repeats on'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var day = 1; day <= 7; day++) ...[
                      if (day > 1) const SizedBox(width: 6),
                      Expanded(
                        child: Tappable(
                          haptic: TapHaptic.selection,
                          semanticLabel: 'Day $day',
                          selected: _weekdays.contains(day),
                          // Editing moves one session, so the day is fixed;
                          // creating can fan the same session across the week.
                          onTap: _isEdit
                              ? null
                              : () => setState(() {
                                    if (!_weekdays.remove(day)) _weekdays.add(day);
                                  }),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _weekdays.contains(day)
                                  ? colors.accentSoft
                                  : scheme.surface,
                              border: Border.all(
                                color: _weekdays.contains(day)
                                    ? scheme.secondary
                                    : scheme.outline,
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.chipRadius),
                            ),
                            child: Text(
                              _dayLabels[day - 1],
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _weekdays.contains(day)
                                    ? colors.accentInk
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_isEdit && _weekdays.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Adds this session to ${_weekdays.length} days.',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: colors.text3,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _Label('Time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Starts',
                        value: _start,
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeField(
                        label: 'Ends',
                        value: _end,
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _save,
                  child: Text(_isEdit ? 'Save session' : 'Add to plan'),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(healthControllerProvider)
                          .deleteWorkoutDay(widget.initial!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(foregroundColor: colors.critical),
                    // Kit's copy rule: name the consequence.
                    child: const Text('Remove session and its logged sets'),
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

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$label ${value.format(context)}',
      child: Container(
        height: AppSpacing.controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: colors.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.text3,
                    ),
                  ),
                  Text(
                    value.format(context),
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

Future<void> showWorkoutPlanSheet(
  BuildContext context, {
  WorkoutDay? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => WorkoutPlanSheet(initial: initial),
  );
}
