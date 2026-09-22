import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/haptics.dart';
import '../../../../app/motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/finance_providers.dart';
import 'account_card.dart' show accountIconValueFor;
import '../../domain/payment_mode.dart';
import '../screens/category_management_screen.dart';

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
    this.paymentMode,
  });

  final int amountMinor;
  final String accountId;
  final DateTime date;
  final String? categoryId;
  final String? note;
  final String? paymentMode;
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
    this.onSwitchLayout,
  });

  final EntryKind kind;
  final List<Account> accounts;
  final List<Category> categories;
  final String currencySymbol;
  final Future<void> Function()? onSwitchLayout;

  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  /// The raw digit buffer, e.g. `"1234"` or `"1234.5"`. Formatting happens on read.
  final _amountController = TextEditingController();
  String? _categoryId;
  late List<Category> _categories;
  late String _accountId;
  late bool _isExpense;
  String? _paymentMode;
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    _categories = List.of(widget.categories);
    _isExpense = widget.kind == EntryKind.expense;
    final initialCategory = _categories.where(
      (category) => category.kind == (_isExpense ? 'expense' : 'income'),
    );
    _categoryId = initialCategory.isEmpty ? null : initialCategory.first.id;
    _paymentMode = paymentModes.first.id;
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _validAmount {
    final value = double.tryParse(_amountController.text.trim());
    return value != null && value.isFinite && value > 0;
  }

  bool get _valid =>
      _validAmount &&
      _accountId.isNotEmpty &&
      _categoryId != null &&
      _paymentMode != null;

  int get _amountMinor {
    final parsed = double.tryParse(_amountController.text) ?? 0;
    return (parsed * 100).round();
  }

  Future<void> _switchLayout() async {
    await widget.onSwitchLayout?.call();
    if (mounted) Navigator.of(context).pop();
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
        paymentMode: _paymentMode,
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

  Future<void> _addCategory() async {
    final result = await showCategoryEditorSheet(
      context,
      fixedKind: _isExpense ? 'expense' : 'income',
    );
    if (result == null) return;

    final category = await ref
        .read(financeControllerProvider)
        .addCategory(
          name: result.name,
          icon: result.icon,
          colorHex: result.colorHex,
          kind: result.kind,
        );
    if (!mounted) return;
    setState(() {
      _categories = [..._categories, category];
      _categoryId = category.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    // An account's glyph comes from its type, the same lookup AccountCard uses.
    final accountTypes = ref.watch(accountTypesProvider).value ?? const [];

    final accent = _isExpense ? colors.spend : colors.finance;
    final relevant = _categories
        .where(
          (category) => category.kind == (_isExpense ? 'expense' : 'income'),
        )
        .toList();

    return Padding(
      // Comp: the sheet stops 52px below the top of the screen.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 52),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
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
                      if (widget.onSwitchLayout != null) ...[
                        Tappable(
                          onTap: _switchLayout,
                          haptic: TapHaptic.light,
                          semanticLabel: 'Full details',
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
                              LucideIcons.list,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
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
                    label: _isExpense
                        ? 'Amount spent *'
                        : 'Amount received *',
                    symbol: widget.currencySymbol,
                    controller: _amountController,
                    errorText: _amountController.text.isNotEmpty && !_validAmount
                        ? 'Enter a positive amount'
                        : null,
                  ),

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
                          iconValue: relevant[i].icon,
                          dotColor: colors.spendCategoryPalette[
                              i % colors.spendCategoryPalette.length],
                          selected: relevant[i].id == _categoryId,
                          onTap: () =>
                              setState(() => _categoryId = relevant[i].id),
                        ),
                      _AddCategoryChip(onTap: _addCategory),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel('Payment mode'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in paymentModes)
                        _PaymentChip(
                          mode: mode,
                          selected: _paymentMode == mode.id,
                          onTap: () => setState(() => _paymentMode = mode.id),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel(_isExpense ? 'Paid from' : 'Credited to'),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final account = widget.accounts[index];
                        return _AccountChip(
                          name: account.name,
                          subtitle: account.type,
                          icon: accountIconValueFor(account.type, accountTypes),
                          selected: account.id == _accountId,
                          onTap: () => setState(() => _accountId = account.id),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What was it for?',
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

            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.primaryButtonHeight,
                  child: FilledButton(
                    onPressed: _valid ? _submit : null,
                    child: Text(_isExpense ? 'Save expense' : 'Save income'),
                  ),
                ),
              ),
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
    required this.controller,
    this.errorText,
  });

  final String label;
  final String symbol;
  final TextEditingController controller;
  final String? errorText;

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
        SizedBox(
          width: 300,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      Text(
                        controller.text.isEmpty ? '0' : controller.text,
                        style: TextStyle(
                          fontFamily: AppFonts.serif,
                          fontSize: 46,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1,
                          color: controller.text.isEmpty
                              ? colors.text3
                              : scheme.onSurface,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 2,
                        height: 38,
                        color: scheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  cursorColor: Colors.transparent,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
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
    required this.iconValue,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? iconValue;
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
            IconOrEmoji(value: iconValue, size: 16, color: dotColor),
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

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: 'Add category',
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 15, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              'Add category',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final PaymentMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      avatar: Icon(mode.icon, size: 16),
      label: Text(mode.label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primary.withValues(alpha: 0.14),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String subtitle;

  /// Icon-name string from the account's type, resolved by [IconOrEmoji].
  final String icon;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconOrEmoji(
              value: icon,
              size: 18,
              color: selected ? colors.accentInk : colors.finance,
            ),
            const SizedBox(width: 10),
            Column(
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
  Future<void> Function()? onSwitchLayout,
}) {
  return showModalBottomSheet<EntryFormResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: false,
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
      onSwitchLayout: onSwitchLayout,
    ),
  );
}
