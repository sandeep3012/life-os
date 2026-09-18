import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/haptics.dart';
import '../../../../app/motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/tappable.dart';

/// Which direction the entry moves money.
enum EntryKind { expense, income }

/// What the sheet collected. Amount is in integer minor units and already signed
/// for [EntryKind] — negative for an expense, positive for income — so callers can
/// hand it straight to `FinanceController.addTransaction`.
class EntryFormResult {
  const EntryFormResult({
    required this.amountMinor,
    required this.accountId,
    required this.date,
    this.categoryId,
    this.note,
  });

  final int amountMinor;
  final String accountId;
  final DateTime date;
  final String? categoryId;
  final String? note;
}

/// The design's entry form: a near-full-height sheet with a fixed header, a
/// scrolling body, and a pinned money keypad.
///
/// Comp structure — top inset 52px, `bg`, top radius 30 with a hairline; a 38px
/// coloured icon well beside a serif title; a centred amount display with the
/// currency mark at 30px, the figure at 46px Newsreader w500 tabular, and a
/// blinking 2px accent caret; wrapping category chips at 38px/r12; a horizontal
/// account picker at r14; then a `surface-2` keypad tray of 46px/r13 keys over a
/// 54px/r16 CTA.
///
/// The comp's recurring block is not here: recurring entries are a different table
/// in this app with their own dedicated sheet, and the add menu routes to it.
class EntryFormSheet extends ConsumerStatefulWidget {
  const EntryFormSheet({
    super.key,
    required this.kind,
    required this.accounts,
    required this.categories,
    required this.currencySymbol,
  });

  final EntryKind kind;
  final List<Account> accounts;
  final List<Category> categories;
  final String currencySymbol;

  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  /// The raw digit buffer, e.g. `"1234"` or `"1234.5"`. Formatting happens on read.
  String _buffer = '';
  String? _categoryId;
  late String _accountId;
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();

  static const _maxIntegerDigits = 8;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isExpense => widget.kind == EntryKind.expense;
  bool get _valid => _amountMinor > 0;

  int get _amountMinor {
    if (_buffer.isEmpty) return 0;
    final parsed = double.tryParse(_buffer) ?? 0;
    return (parsed * 100).round();
  }

  /// Comp: grouped Indian-style live as digits are entered — `₹1,85,000`, never
  /// `₹185,000`. The integer part is grouped; any decimals are shown verbatim so
  /// a half-typed `12.` doesn't jump around.
  String get _display {
    if (_buffer.isEmpty) return '0';
    final dot = _buffer.indexOf('.');
    final intPart = dot < 0 ? _buffer : _buffer.substring(0, dot);
    final grouped = NumberFormat.decimalPattern(
      'en_IN',
    ).format(int.tryParse(intPart) ?? 0);
    if (dot < 0) return grouped;
    return '$grouped${_buffer.substring(dot)}';
  }

  void _press(String key) {
    ref.read(hapticsProvider).selection();
    setState(() {
      final dot = _buffer.indexOf('.');
      if (key == '.') {
        if (dot >= 0) return;
        _buffer = _buffer.isEmpty ? '0.' : '$_buffer.';
        return;
      }
      if (dot >= 0) {
        // Max two decimal places.
        if (_buffer.length - dot - 1 >= 2) return;
      } else {
        if (_buffer.length >= _maxIntegerDigits) return;
        if (_buffer == '0') _buffer = '';
      }
      _buffer = '$_buffer$key';
    });
  }

  void _backspace() {
    ref.read(hapticsProvider).selection();
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  Future<void> _submit() async {
    if (!_valid) {
      // Comp: an invalid submit fires a heavy haptic and does not save.
      await ref.read(hapticsProvider).heavy();
      return;
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      EntryFormResult(
        amountMinor: _isExpense ? -_amountMinor : _amountMinor,
        accountId: _accountId,
        date: _date,
        categoryId: _categoryId,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final accent = _isExpense ? colors.spend : colors.finance;
    final relevant = widget.categories;

    return Padding(
      // Comp: the sheet stops 52px below the top of the screen.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 52),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: scheme.outline)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ---- fixed header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      InitialWell(
                        color: accent,
                        size: 38,
                        radius: 12,
                        icon: _isExpense
                            ? LucideIcons.arrowDownLeft
                            : LucideIcons.arrowUpRight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isExpense ? 'New expense' : 'New income',
                              style: TextStyle(
                                fontFamily: AppFonts.serif,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              _isExpense ? 'One-off spend' : 'Salary, refunds',
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 12,
                                color: colors.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tappable(
                        onTap: () => Navigator.of(context).pop(),
                        haptic: TapHaptic.light,
                        semanticLabel: 'Close',
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            border: Border.all(color: scheme.outline),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- scrolling body ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  _AmountDisplay(
                    label: _isExpense ? 'Amount spent' : 'Amount received',
                    symbol: widget.currencySymbol,
                    value: _display,
                    empty: _buffer.isEmpty,
                  ),

                  if (relevant.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(_isExpense ? 'Category' : 'Source'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < relevant.length; i++)
                          _Chip(
                            label: relevant[i].name,
                            dotColor: colors.spendCategoryPalette[
                                i % colors.spendCategoryPalette.length],
                            selected: relevant[i].id == _categoryId,
                            onTap: () =>
                                setState(() => _categoryId = relevant[i].id),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  _FieldLabel(_isExpense ? 'Paid from' : 'Credited to'),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final account = widget.accounts[index];
                        return _AccountChip(
                          name: account.name,
                          subtitle: account.type,
                          selected: account.id == _accountId,
                          onTap: () => setState(() => _accountId = account.id),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel('Note'),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'What was it for?',
                    ),
                  ),

                  const SizedBox(height: 12),
                  Tappable(
                    onTap: _pickDate,
                    haptic: TapHaptic.light,
                    semanticLabel: 'Change date',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.controlRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendarDays,
                            size: 17,
                            color: colors.text3,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dateLabel(_date),
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: colors.text3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- pinned keypad tray ----
            _Keypad(
              onKey: _press,
              onBackspace: _backspace,
              onSubmit: _submit,
              enabled: _valid,
              saveLabel: _isExpense ? 'Save expense' : 'Save income',
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final formatted = DateFormat('d MMM yyyy').format(date);
    return isToday ? 'Today · $formatted' : formatted;
  }
}

/// Comp: a centred overline over the currency mark, the figure, and a blinking
/// caret. The figure sits in `text3` until something is entered.
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.label,
    required this.symbol,
    required this.value,
    required this.empty,
  });

  final String label;
  final String symbol;
  final String value;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: colors.text3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: colors.text3,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  color: empty ? colors.text3 : scheme.onSurface,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(width: 2, height: 38, color: scheme.secondary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(duration: 900.ms),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

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

/// Comp: 38px tall, radius 12, an 8px swatch then a 13px w700 label. Selected
/// takes `accentSoft` behind an `accent` border with `accentInk` text.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.selection,
      semanticLabel: label,
      selected: selected,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : scheme.surface,
          border: Border.all(
            color: selected ? scheme.secondary : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? colors.accentInk : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.selection,
      semanticLabel: name,
      selected: selected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : scheme.surface,
          border: Border.all(
            color: selected ? scheme.secondary : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? colors.accentInk : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11,
                color: colors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comp: a `surface-2` tray with a `border-2` top edge, a 3×4 grid of 46px
/// radius-13 keys set in Newsreader 21px, and the CTA below at 54px/r16. The CTA
/// drops to 60% opacity on a `text3` fill until an amount exists.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onKey,
    required this.onBackspace,
    required this.onSubmit,
    required this.enabled,
    required this.saveLabel,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool enabled;
  final String saveLabel;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Tappable(
                          onTap: row[i] == '<'
                              ? onBackspace
                              : () => onKey(row[i]),
                          semanticLabel: row[i] == '<' ? 'Delete' : row[i],
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.iconButtonRadius,
                              ),
                            ),
                            child: row[i] == '<'
                                ? Icon(
                                    LucideIcons.delete,
                                    size: 19,
                                    color: scheme.onSurface,
                                  )
                                : Text(
                                    row[i],
                                    style: TextStyle(
                                      fontFamily: AppFonts.serif,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Tappable(
              onTap: onSubmit,
              semanticLabel: saveLabel,
              child: Opacity(
                opacity: enabled ? 1 : 0.6,
                child: Container(
                  height: AppSpacing.primaryButtonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? scheme.primary : colors.text3,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.primaryButtonRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        saveLabel,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.check,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ],
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

/// Presents [EntryFormSheet] with the comp's sheet chrome.
Future<EntryFormResult?> showEntryFormSheet(
  BuildContext context, {
  required EntryKind kind,
  required List<Account> accounts,
  required List<Category> categories,
  required String currencySymbol,
}) {
  return showModalBottomSheet<EntryFormResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    // Comp: 420ms in on a curve that overshoots slightly, 190ms out.
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.sheetOpen,
      curve: AppMotion.sheetIn,
      reverseDuration: AppMotion.sheetClose,
      reverseCurve: AppMotion.sheetOut,
    ),
    builder: (context) => EntryFormSheet(
      kind: kind,
      accounts: accounts,
      categories: categories,
      currencySymbol: currencySymbol,
    ),
  );
}
