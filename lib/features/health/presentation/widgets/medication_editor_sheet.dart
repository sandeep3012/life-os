import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
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
        timesCsv: '08:00',
        reminderEnabled: _remind,
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
        timesCsv: widget.initial!.timesCsv,
        reminderEnabled: _remind,
        stockLeft: stock,
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
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
                  widget.initial == null ? 'New medication' : 'Edit medication',
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
                _ChipRow(
                  options: _slots,
                  selected: _slot,
                  onSelect: (v) => setState(() => _slot = v),
                ),
                const SizedBox(height: 16),
                _Label('Repeats'),
                const SizedBox(height: 8),
                _ChipRow(
                  options: _frequencies,
                  selected: _frequency,
                  onSelect: (v) => setState(() => _frequency = v),
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
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.initial == null ? 'Add medication' : 'Save changes',
                  ),
                ),
              ],
            ),
          ),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          Tappable(
            haptic: TapHaptic.selection,
            semanticLabel: entry.value,
            selected: entry.key == selected,
            onTap: () => onSelect(entry.key),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.key == selected ? colors.accentSoft : scheme.surface,
                border: Border.all(
                  color: entry.key == selected ? scheme.secondary : scheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: entry.key == selected
                      ? colors.accentInk
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showMedicationEditorSheet(
  BuildContext context, {
  Medication? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => MedicationEditorSheet(initial: initial),
  );
}
