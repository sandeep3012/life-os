import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../application/habits_providers.dart';

class QuickAddHabitResult {
  const QuickAddHabitResult({
    required this.name,
    this.categoryId,
    this.reminderEnabled = false,
    this.reminderHour,
    this.reminderMinute,
    this.reminderMode = ReminderMode.notification,
  });

  final String name;
  final String? categoryId;
  final bool reminderEnabled;

  /// Only set when [reminderEnabled] is true.
  final int? reminderHour;
  final int? reminderMinute;
  final ReminderMode reminderMode;
}

/// Sentinel dropdown value for the trailing "Add new category" entry —
/// distinct from any real category id (same idiom as the finance category
/// pickers in `quick_add_transaction_sheet.dart`/`quick_add_budget_sheet.dart`).
const _addCategoryValue = '__add_category__';

Future<QuickAddHabitResult?> showQuickAddHabitSheet(
  BuildContext context, {
  required List<Category> categories,
  Habit? initial,
}) {
  return showModalBottomSheet<QuickAddHabitResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddHabitSheet(categories: categories, initial: initial),
  );
}

class _QuickAddHabitSheet extends ConsumerStatefulWidget {
  const _QuickAddHabitSheet({required this.categories, this.initial});

  final List<Category> categories;
  final Habit? initial;

  @override
  ConsumerState<_QuickAddHabitSheet> createState() => _QuickAddHabitSheetState();
}

class _QuickAddHabitSheetState extends ConsumerState<_QuickAddHabitSheet> {
  late final _nameController = TextEditingController(text: widget.initial?.name);
  late List<Category> _categories = List.of(widget.categories);
  late String? _categoryId = widget.initial?.categoryId;
  late bool _reminderEnabled = widget.initial?.reminderEnabled ?? false;
  late TimeOfDay _reminderTime = widget.initial?.reminderHour != null
      ? TimeOfDay(hour: widget.initial!.reminderHour!, minute: widget.initial!.reminderMinute!)
      : const TimeOfDay(hour: 20, minute: 0);
  late ReminderMode _reminderMode = ReminderMode.fromStorage(
    widget.initial?.reminderMode ?? 'notification',
  );

  /// Forces the (uncontrolled) category dropdown back to `_categoryId` after
  /// "Add new category" resolves or is cancelled — same fix as the identical
  /// field in the finance category pickers.
  int _categoryFieldEpoch = 0;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditorSheet(context, fixedKind: 'habit');
    if (result == null) {
      if (mounted) setState(() => _categoryFieldEpoch++);
      return;
    }
    final category = await ref.read(habitsControllerProvider).createHabitCategory(
      name: result.name,
      icon: result.icon,
      colorHex: result.colorHex,
    );
    if (!mounted) return;
    setState(() {
      _categories = [..._categories, category];
      _categoryId = category.id;
      _categoryFieldEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit habit' : 'New habit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Morning workout'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('$_categoryId#$_categoryFieldEpoch'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(resolveIcon(c.icon), size: 16),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  ),
                const DropdownMenuItem(
                  value: _addCategoryValue,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Add new category'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == _addCategoryValue) {
                  _addCategory();
                } else {
                  setState(() => _categoryId = value);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: const Text('Daily notification for this habit'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
            if (_reminderEnabled)
              TextButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(_reminderTime.format(context)),
              ),
            if (_reminderEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: SegmentedButton<ReminderMode>(
                  segments: const [
                    ButtonSegment(
                      value: ReminderMode.notification,
                      label: Text('Notification'),
                      icon: Icon(Icons.notifications_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ReminderMode.alarm,
                      label: Text('Alarm'),
                      icon: Icon(Icons.alarm_rounded, size: 16),
                    ),
                  ],
                  selected: {_reminderMode},
                  onSelectionChanged: (s) => setState(() => _reminderMode = s.first),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nameController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        QuickAddHabitResult(
                          name: _nameController.text.trim(),
                          categoryId: _categoryId,
                          reminderEnabled: _reminderEnabled,
                          reminderHour: _reminderEnabled ? _reminderTime.hour : null,
                          reminderMinute: _reminderEnabled ? _reminderTime.minute : null,
                          reminderMode: _reminderMode,
                        ),
                      ),
                child: Text(_isEditing ? 'Save changes' : 'Add habit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
