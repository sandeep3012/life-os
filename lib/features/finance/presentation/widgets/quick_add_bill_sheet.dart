import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import 'account_option_row.dart';

class QuickAddBillResult {
  const QuickAddBillResult({
    required this.name,
    this.accountId,
    this.categoryId,
    required this.amountMinor,
    required this.dueDate,
    required this.frequency,
    this.reminderEnabled = true,
    this.reminderMode = ReminderMode.notification,
    this.reminderDaysBefore = 0,
  });

  final String name;
  final String? accountId;
  final String? categoryId;

  /// Positive magnitude — how much the bill is for.
  final int amountMinor;
  final DateTime dueDate;

  /// once | monthly | yearly
  final String frequency;
  final bool reminderEnabled;
  final ReminderMode reminderMode;
  final int reminderDaysBefore;
}

const _frequencies = [('once', 'One-time'), ('monthly', 'Monthly'), ('yearly', 'Yearly')];

Future<QuickAddBillResult?> showQuickAddBillSheet(
  BuildContext context, {
  required List<Account> accounts,
  required List<AccountType> accountTypes,
  required List<Category> categories,
  required String currencySymbol,
  Bill? initial,
}) {
  return showCompactEditorSheet<QuickAddBillResult>(
    context: context,
    builder: (context) => _QuickAddBillSheet(
      accounts: accounts,
      accountTypes: accountTypes,
      categories: categories,
      currencySymbol: currencySymbol,
      initial: initial,
    ),
  );
}

class _QuickAddBillSheet extends StatefulWidget {
  const _QuickAddBillSheet({
    required this.accounts,
    required this.accountTypes,
    required this.categories,
    required this.currencySymbol,
    this.initial,
  });

  final List<Account> accounts;

  /// Supplies each account's glyph; see [OptionRow.account].
  final List<AccountType> accountTypes;
  final List<Category> categories;
  final String currencySymbol;

  /// Non-null when editing an existing bill.
  final Bill? initial;

  @override
  State<_QuickAddBillSheet> createState() => _QuickAddBillSheetState();
}

class _QuickAddBillSheetState extends State<_QuickAddBillSheet> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _amountController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.amountMinor / 100).toStringAsFixed(2),
  );
  late String? _accountId = widget.initial?.accountId;
  late String? _categoryId = widget.initial?.categoryId;
  late DateTime _dueDate =
      widget.initial?.dueDate ?? DateTime.now().add(const Duration(days: 1));
  late String _frequency = widget.initial?.frequency ?? 'monthly';
  late bool _reminderEnabled = widget.initial?.reminderEnabled ?? true;
  late ReminderMode _reminderMode = widget.initial == null
      ? ReminderMode.notification
      : ReminderMode.fromStorage(widget.initial!.reminderMode);
  late int _reminderDaysBefore = widget.initial?.reminderDaysBefore ?? 0;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _nameController.text.trim().isNotEmpty &&
        (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

    return CompactEditorSheet(
      title: _isEditing ? 'Edit bill' : 'New bill',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Electricity, Credit card'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'Amount (${widget.currencySymbol})'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Usually paid from (optional)',
              ),
              items: [
                for (final a in widget.accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: OptionRow.account(a, widget.accountTypes),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconOrEmoji(value: c.icon, size: 16),
                        const SizedBox(width: dropdownIconGap),
                        Text(c.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            Text('Repeats', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in _frequencies)
                  ChoiceChip(
                    label: Text(label),
                    selected: _frequency == value,
                    onSelected: (_) => setState(() => _frequency = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due date'),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(DateFormat.yMMMd().format(_dueDate)),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: const Text('Nudge before the due date'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
            if (_reminderEnabled) ...[
              DropdownButtonFormField<int>(
                initialValue: _reminderDaysBefore,
                decoration: const InputDecoration(
                  labelText: 'Remind',
                  prefixIcon: Icon(LucideIcons.bellRing, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('On the due date')),
                  DropdownMenuItem(value: 1, child: Text('1 day before')),
                  DropdownMenuItem(value: 3, child: Text('3 days before')),
                  DropdownMenuItem(value: 7, child: Text('1 week before')),
                ],
                onChanged: (v) => setState(() => _reminderDaysBefore = v ?? 0),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ReminderMode>(
                segments: const [
                  ButtonSegment(
                    value: ReminderMode.notification,
                    label: Text('Notification'),
                    icon: Icon(LucideIcons.bell, size: 16),
                  ),
                  ButtonSegment(
                    value: ReminderMode.alarm,
                    label: Text('Alarm'),
                    icon: Icon(LucideIcons.alarmClock, size: 16),
                  ),
                ],
                selected: {_reminderMode},
                onSelectionChanged: (s) => setState(() => _reminderMode = s.first),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit
                    ? () {
                        final rupees = double.parse(_amountController.text.trim());
                        final minor = (rupees * 100).round();
                        Navigator.of(context).pop(
                          QuickAddBillResult(
                            name: _nameController.text.trim(),
                            accountId: _accountId,
                            categoryId: _categoryId,
                            amountMinor: minor,
                            dueDate: _dueDate,
                            frequency: _frequency,
                            reminderEnabled: _reminderEnabled,
                            reminderMode: _reminderMode,
                            reminderDaysBefore: _reminderDaysBefore,
                          ),
                        );
                      }
                    : null,
                child: Text(_isEditing ? 'Save changes' : 'Add bill'),
              ),
            ),
          ],
        ),
    );
  }
}
