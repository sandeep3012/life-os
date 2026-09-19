import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/tappable.dart';
import '../../../documents/application/documents_providers.dart';
import '../../application/finance_providers.dart';
import '../../domain/payment_mode.dart';
import '../screens/category_management_screen.dart';

class QuickAddTransactionResult {
  const QuickAddTransactionResult({
    required this.accountId,
    this.categoryId,
    required this.merchant,
    required this.amountMinor,
    required this.date,
    this.paymentMode,
  });

  final String accountId;
  final String? categoryId;
  final String merchant;

  /// Already signed: negative for expense, positive for income.
  final int amountMinor;
  final DateTime date;
  final String? paymentMode;
}

Future<QuickAddTransactionResult?> showQuickAddTransactionSheet(
  BuildContext context, {
  required List<Account> accounts,
  required List<Category> categories,
  required String currencySymbol,
  Transaction? initial,
  bool initialIsExpense = true,
  Future<void> Function()? onSwitchLayout,
}) {
  return showModalBottomSheet<QuickAddTransactionResult>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _QuickAddTransactionSheet(
        accounts: accounts,
        categories: categories,
        currencySymbol: currencySymbol,
        initial: initial,
        initialIsExpense: initialIsExpense,
        onSwitchLayout: onSwitchLayout,
      ),
    ),
  );
}

class _QuickAddTransactionSheet extends ConsumerStatefulWidget {
  const _QuickAddTransactionSheet({
    required this.accounts,
    required this.categories,
    required this.currencySymbol,
    this.initial,
    required this.initialIsExpense,
    this.onSwitchLayout,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final String currencySymbol;
  final Transaction? initial;
  final bool initialIsExpense;
  final Future<void> Function()? onSwitchLayout;

  @override
  ConsumerState<_QuickAddTransactionSheet> createState() =>
      _QuickAddTransactionSheetState();
}

/// Sentinel dropdown value for the trailing "Add new category" entry —
/// distinct from any real category id.
const _addCategoryValue = '__add_category__';

class _QuickAddTransactionSheetState
    extends ConsumerState<_QuickAddTransactionSheet> {
  late final _merchantController = TextEditingController(
    text: widget.initial?.merchant,
  );
  late final _amountController = TextEditingController(
    text: widget.initial == null
        ? null
        : (widget.initial!.amountMinor.abs() / 100).toStringAsFixed(2),
  );
  late String _accountId =
      widget.initial?.accountId ?? widget.accounts.first.id;
  late List<Category> _categories = List.of(widget.categories);
  late String? _categoryId = widget.initial?.categoryId;
  late final bool _isExpense = widget.initial == null
      ? widget.initialIsExpense
      : widget.initial!.amountMinor < 0;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late String? _paymentMode = widget.initial?.paymentMode;

  /// See the identical field in `_QuickAddBudgetSheetState` — forces the
  /// (uncontrolled) category dropdown back to `_categoryId` after "Add new
  /// category" resolves or is cancelled.
  int _categoryFieldEpoch = 0;

  bool get _isEditing => widget.initial != null;

  bool get _validAmount {
    final value = double.tryParse(_amountController.text.trim());
    return value != null && value.isFinite && value > 0;
  }

  Future<void> _switchLayout() async {
    await widget.onSwitchLayout?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    final initialCategory = _categories.where(
      (category) => category.kind == (_isExpense ? 'expense' : 'income'),
    );
    _categoryId ??= initialCategory.isEmpty ? null : initialCategory.first.id;
    _paymentMode ??= paymentModes.first.id;
    _merchantController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditorSheet(
      context,
      fixedKind: _isExpense ? 'expense' : 'income',
    );
    if (result == null) {
      if (mounted) setState(() => _categoryFieldEpoch++);
      return;
    }
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
      _categoryFieldEpoch++;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent = _isExpense ? colors.spend : colors.finance;
    final canSubmit =
        _validAmount &&
        _accountId.isNotEmpty &&
        _categoryId != null &&
        _paymentMode != null;
    final relevantCategories = _categories
        .where(
          (category) => category.kind == (_isExpense ? 'expense' : 'income'),
        )
        .toList();

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
                        _isEditing
                            ? (_isExpense ? 'Edit expense' : 'Edit income')
                            : (_isExpense ? 'New expense' : 'New income'),
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
                    semanticLabel: 'Quick entry',
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
                        LucideIcons.zap,
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
            const SizedBox(height: 20),
            TextField(
              controller: _merchantController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant / description',
                hintText: 'Merchant / description',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (${widget.currencySymbol}) *',
                hintText: 'Amount (${widget.currencySymbol})',
                errorText: _amountController.text.isNotEmpty && !_validAmount
                    ? 'Enter a positive amount'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final a in widget.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (value) => setState(() => _accountId = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('$_categoryId#$_categoryFieldEpoch'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in relevantCategories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconOrEmoji(value: c.icon, size: 16),
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
                      Icon(LucideIcons.circlePlus, size: 16),
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
            const SizedBox(height: 12),
            Text(
              'Payment mode',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in paymentModes)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 16),
                    label: Text(m.label),
                    selected: _paymentMode == m.id,
                    onSelected: (_) => setState(() => _paymentMode = m.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(DateFormat.yMMMd().format(_date)),
                  ],
                ),
              ),
            ),
            // Only meaningful once the transaction has an id to attach to —
            // shown on the edit path, not while composing a brand-new one.
            if (_isEditing) ...[
              const SizedBox(height: 12),
              _ReceiptSection(transactionId: widget.initial!.id),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit
                    ? () {
                        final rupees = double.parse(
                          _amountController.text.trim(),
                        );
                        final minor = (rupees * 100).round();
                        Navigator.of(context).pop(
                          QuickAddTransactionResult(
                            accountId: _accountId,
                            categoryId: _categoryId,
                            merchant: _merchantController.text.trim().isEmpty
                                ? (_isExpense ? 'Expense' : 'Income')
                                : _merchantController.text.trim(),
                            amountMinor: _isExpense ? -minor : minor,
                            date: _date,
                            paymentMode: _paymentMode,
                          ),
                        );
                      }
                    : null,
                child: Text(_isEditing ? 'Save changes' : 'Add transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only when editing an existing transaction — attaching a receipt
/// writes to the DB immediately (unlike the rest of this sheet's fields,
/// which wait for "Save changes") because it needs a real transaction id to
/// link against, and there's no reason to make the user re-open the sheet
/// just to confirm a photo they already picked.
class _ReceiptSection extends ConsumerWidget {
  const _ReceiptSection({required this.transactionId});

  final String transactionId;

  Future<void> _pickReceipt(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) return;
    await ref
        .read(financeControllerProvider)
        .attachReceipt(
          transactionId: transactionId,
          source: File(picked.path),
          originalName: p.basename(picked.path),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final transaction = transactions
        .where((t) => t.id == transactionId)
        .firstOrNull;
    final receipt = ref.watch(
      documentByIdProvider(transaction?.receiptDocumentId),
    );

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Receipt'),
      child: Row(
        children: [
          if (receipt != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ReceiptThumbnail(document: receipt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                receipt.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Remove receipt',
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => ref
                  .read(financeControllerProvider)
                  .removeReceipt(transactionId),
            ),
          ] else
            Expanded(
              child: TextButton.icon(
                onPressed: () => _pickReceipt(context, ref),
                icon: const Icon(LucideIcons.camera, size: 18),
                label: const Text('Attach receipt'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptThumbnail extends StatefulWidget {
  const _ReceiptThumbnail({required this.document});

  final Document document;

  @override
  State<_ReceiptThumbnail> createState() => _ReceiptThumbnailState();
}

class _ReceiptThumbnailState extends State<_ReceiptThumbnail> {
  final _storage = FileStorageService();
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReceiptThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) _load();
  }

  void _load() {
    final path = widget.document.thumbnailPath ?? widget.document.filePath;
    _storage.absoluteFile(path).then((f) {
      if (mounted) setState(() => _file = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) return const SizedBox(width: 40, height: 40);
    return Image.file(
      _file!,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox(
        width: 40,
        height: 40,
        child: Icon(LucideIcons.receipt, size: 18),
      ),
    );
  }
}
