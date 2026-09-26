import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/health_providers.dart';

/// The comp's medication schedule sheet: name, dose note, which part of the day
/// it belongs to, how often it repeats, the weekdays it applies on, the doses in
/// hand, and a reminder toggle.
///
/// Pass [initial] to edit an existing medication; omit it to create one.
class MedicationEditorSheet extends ConsumerStatefulWidget {
  const MedicationEditorSheet({super.key, this.initial});

  final Medication? initial;

  @override
  ConsumerState<MedicationEditorSheet> createState() =>
      _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends ConsumerState<MedicationEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late final TextEditingController _stock;
  late String _slot;
  late String _frequency;
  late Set<int> _days;
  late bool _remind;
  late ReminderMode _reminderMode;
  late TimeOfDay _reminderTime;

  static const _slots = {'am': 'Morning', 'pm': 'Afternoon', 'night': 'Night'};
  static const _frequencies = {
    'daily': 'Daily',
    'alt': 'Alternate days',
    'weekly': 'Weekly',
  };
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: m?.name ?? '');
    _note = TextEditingController(text: m?.dosageNote ?? '');
    _stock = TextEditingController(text: m?.stockLeft?.toString() ?? '');
    _slot = m?.slot ?? 'am';
    _frequency = m?.frequency ?? 'daily';
    _days = (m?.daysCsv ?? '1,2,3,4,5,6,7')
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    _remind = m?.reminderEnabled ?? false;
    _reminderMode = ReminderMode.fromStorage(m?.reminderMode ?? 'notification');
    _reminderTime = _firstTimeOf(m?.timesCsv);
  }

  /// A medication can hold several dose times, but the sheet only edits the
  /// first — a multi-time schedule is created elsewhere and round-trips
  /// untouched (see `_timesCsv`).
  static TimeOfDay _firstTimeOf(String? csv) {
    final bits = (csv ?? '').split(',').first.trim().split(':');
    final hour = bits.length == 2 ? int.tryParse(bits[0]) : null;
    final minute = bits.length == 2 ? int.tryParse(bits[1]) : null;
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String get _timesCsv {
    String two(int v) => v.toString().padLeft(2, '0');
    final first = '${two(_reminderTime.hour)}:${two(_reminderTime.minute)}';
    // Preserve any later doses the sheet doesn't surface.
    final rest = (widget.initial?.timesCsv ?? '').split(',').skip(1);
    return [
      first,
      ...rest.map((t) => t.trim()).where((t) => t.isNotEmpty),
    ].join(',');
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final controller = ref.read(healthControllerProvider);
    final stock = int.tryParse(_stock.text.trim());
    final daysCsv = (_days.toList()..sort()).join(',');

    if (widget.initial == null) {
      await controller.addMedication(
        name: name,
        dosageNote: _note.text.trim(),
        slot: _slot,
        frequency: _frequency,
        daysCsv: daysCsv,
        timesCsv: _timesCsv,
        reminderEnabled: _remind,
        reminderMode: _reminderMode.storageValue,
        stockLeft: stock,
      );
    } else {
      await controller.updateMedication(
        id: widget.initial!.id,
        name: name,
        dosageNote: _note.text.trim(),
        slot: _slot,
        frequency: _frequency,
        daysCsv: daysCsv,
        timesCsv: _timesCsv,
        reminderEnabled: _remind,
        reminderMode: _reminderMode.storageValue,
        stockLeft: stock,
      );
    }
    // The name goes back to the caller, which owns the save acknowledgement —
    // this sheet's context is gone the moment it pops.
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    return CompactEditorSheet(
      title: widget.initial == null ? 'New medication' : 'Edit medication',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Dose note',
              hintText: '1 tablet · with breakfast',
            ),
          ),
          const SizedBox(height: 16),
          _Label('Time of day'),
          const SizedBox(height: 8),
          // A rail rather than wrapped chips: three mutually exclusive options
          // belong on one row, and this is the segmented control the rest of
          // the app already uses (Tasks/Habits, Recent/Starred/Due).
          AppTabRail<String>(
            value: _slot,
            labels: _slots,
            onChanged: (v) => setState(() => _slot = v),
          ),
          const SizedBox(height: 16),
          _Label('Repeats'),
          const SizedBox(height: 8),
          AppTabRail<String>(
            value: _frequency,
            labels: _frequencies,
            onChanged: (v) => setState(() => _frequency = v),
          ),
          if (_frequency != 'daily') ...[
            const SizedBox(height: 16),
            _Label('On these days'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var day = 1; day <= 7; day++) ...[
                  if (day > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Tappable(
                      haptic: TapHaptic.selection,
                      semanticLabel: 'Day $day',
                      selected: _days.contains(day),
                      onTap: () => setState(() {
                        if (!_days.remove(day)) _days.add(day);
                      }),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _days.contains(day)
                              ? colors.accentSoft
                              : scheme.surface,
                          border: Border.all(
                            color: _days.contains(day)
                                ? scheme.secondary
                                : scheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          _dayLabels[day - 1],
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _days.contains(day)
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
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Doses in hand',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: Text(
              'Remind me',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            subtitle: const Text('Notify at the dose time'),
          ),
          if (_remind) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickReminderTime,
                icon: const Icon(LucideIcons.clock, size: 16),
                label: Text(_reminderTime.format(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: AppTabRail<ReminderMode>(
                value: _reminderMode,
                labels: const {
                  ReminderMode.notification: 'Notification',
                  ReminderMode.alarm: 'Alarm',
                },
                icons: const {
                  ReminderMode.notification: LucideIcons.bell,
                  ReminderMode.alarm: LucideIcons.alarmClock,
                },
                onChanged: (v) => setState(() => _reminderMode = v),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(
                widget.initial == null ? 'Add medication' : 'Save changes',
              ),
            ),
          ),
        ],
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

Future<void> showMedicationEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  Medication? initial,
}) async {
  final saved = await showCompactEditorSheet<String>(
    context: context,
    builder: (context) => MedicationEditorSheet(initial: initial),
  );
  if (saved == null || !context.mounted) return;
  await showSaveFeedback(
    context,
    ref,
    title: initial == null ? 'Medication saved' : 'Medication updated',
    message: initial == null
        ? '“$saved” is on your schedule.'
        : 'Changes to “$saved” were saved.',
  );
}
