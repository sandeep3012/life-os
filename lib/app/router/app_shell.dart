import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/currency_utils.dart';
import '../../core/widgets/success_overlay.dart';
import '../../core/widgets/tappable.dart';
import '../../features/finance/application/finance_providers.dart';
import '../../features/finance/presentation/widgets/entry_form_sheet.dart';
import '../../features/home/presentation/widgets/add_menu_sheet.dart';
import '../../features/settings/application/settings_providers.dart';
import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'route_paths.dart';

/// Bottom-nav shell. Four destinations either side of a centre add button, which
/// is the layout the design handoff specifies — the comp's old "More" tab is
/// retired into the sidebar drawer, where every destination that lived behind it
/// now appears.
///
/// Nav indices still map 1:1 onto the router's first four `StatefulShellBranch`es
/// (home, finance, tasks, calendar); the fifth (`more`) branch is reached by
/// route from the drawer rather than by index.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _exitConfirmationWindow = Duration(seconds: 2);
  DateTime? _lastExitAttempt;

  /// Drives the comp's 135° plus rotation while the add menu is open.
  bool _addMenuOpen = false;

  static const _destinations = [
    AppNavDestination(LucideIcons.layoutDashboard, LucideIcons.layoutDashboard, 'Home'),
    AppNavDestination(LucideIcons.wallet, LucideIcons.wallet, 'Finance'),
    AppNavDestination(LucideIcons.listChecks, LucideIcons.listChecks, 'Tasks'),
    AppNavDestination(LucideIcons.calendar, LucideIcons.calendar, 'Calendar'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // A branch route handles its own back navigation before this root shell
      // sees it. At a branch root, intercepting here lets Android return to
      // Home instead of exiting the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleSystemBack(didPop),
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: AppFloatingNavBar(
          destinations: _destinations,
          selectedIndex: widget.navigationShell.currentIndex,
          addMenuOpen: _addMenuOpen,
          onAdd: _openAddMenu,
          onSelected: (index) => widget.navigationShell.goBranch(
            index,
            // initialLocation: index == widget.navigationShell.currentIndex,
            // Bottom tabs are launch points in LifeOS, not history buckets:
            // every selection starts at the tab's root destination.
            initialLocation: true,
          ),
        ),
      ),
    );
  }

  /// The comp offers six tiles, four of which map onto flows this build actually
  /// has. Investment and Recurring SIP are omitted: there is no investments
  /// module, and a tile that opens nothing is worse than no tile.
  Future<void> _openAddMenu() async {
    final colors = context.appColors;
    setState(() => _addMenuOpen = true);

    await showAddMenuSheet(
      context,
      items: [
        AddMenuItem(
          label: 'Expense',
          subtitle: 'One-off spend',
          icon: LucideIcons.arrowDownLeft,
          color: colors.spend,
          onTap: () => _addEntry(EntryKind.expense),
        ),
        AddMenuItem(
          label: 'Income',
          subtitle: 'Salary, refunds',
          icon: LucideIcons.arrowUpRight,
          color: colors.finance,
          onTap: () => _addEntry(EntryKind.income),
        ),
        AddMenuItem(
          label: 'Recurring',
          subtitle: 'Auto-adds on schedule',
          icon: LucideIcons.refreshCw,
          color: colors.aiAnalyser,
          onTap: () => context.go(RoutePaths.recurringTransactions),
        ),
        AddMenuItem(
          label: 'Account',
          subtitle: 'Bank, card, cash',
          icon: LucideIcons.landmark,
          color: colors.tasks,
          onTap: () => context.go(RoutePaths.finance),
        ),
      ],
    );

    if (mounted) setState(() => _addMenuOpen = false);
  }

  /// Opens the design's keypad entry sheet, then persists through the finance
  /// module's existing controller rather than duplicating the save path here.
  Future<void> _addEntry(EntryKind kind) async {
    final accounts = ref.read(transactableAccountsProvider);
    final categories = ref.read(categoriesProvider).value ?? const [];
    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Add an account first')),
        );
      return;
    }

    final result = await showEntryFormSheet(
      context,
      kind: kind,
      accounts: accounts,
      categories: categories,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
    );
    if (result == null) return;
    await ref.read(financeControllerProvider).addTransaction(
      accountId: result.accountId,
      categoryId: result.categoryId,
      merchant: result.note ?? (kind == EntryKind.expense ? 'Expense' : 'Income'),
      amountMinor: result.amountMinor,
      date: result.date,
    );

    if (!mounted) return;
    // Comp copy: "Expense saved — ₹420 logged to HDFC Bank."
    final account = accounts.where((a) => a.id == result.accountId);
    final where = account.isEmpty ? 'your ledger' : account.first.name;
    final amount = formatMinor(
      result.amountMinor.abs(),
      currencyCode: ref.read(settingsProvider).currencyCode,
      showDecimals: false,
    );
    await showSuccessOverlay(
      context,
      title: result.amountMinor > 0 ? 'Income saved' : 'Expense saved',
      message: '$amount logged to $where.',
    );
  }

  void _handleSystemBack(bool didPop) {
    if (didPop || Theme.of(context).platform != TargetPlatform.android) return;

    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }

    final now = DateTime.now();
    if (_lastExitAttempt != null && now.difference(_lastExitAttempt!) <= _exitConfirmationWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastExitAttempt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitConfirmationWindow,
        ),
      );
  }
}

class AppNavDestination {
  const AppNavDestination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The design comp's bottom nav: a lifted pill inset from the screen edges
/// rather than a full-width bar — `left:14px; right:14px; bottom:14px;
/// height:66px; border-radius:24px; background:var(--raised);
/// border:1px solid var(--border); box-shadow:0 12px 30px -12px rgba(0,0,0,.35)`
/// — with the active item in the accent and the rest in the third text tone.
///
/// The comp floats this over content that carries its own `padding-bottom:108px`
/// to clear it. This sits in the [Scaffold.bottomNavigationBar] slot instead, so
/// Scaffold reserves its height and no screen needs per-screen bottom padding;
/// the visual result is the same pill, but content stops above it rather than
/// scrolling underneath.
class AppFloatingNavBar extends StatelessWidget {
  const AppFloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.onAdd,
    this.addMenuOpen = false,
  });

  static const double _pillHeight = 66;
  static const double _inset = 14;

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// When set, a centre add button is inserted between the two halves of the bar.
  final VoidCallback? onAdd;

  /// Rotates the plus to 135°, per the comp.
  final bool addMenuOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, _inset),
        child: Container(
          height: _pillHeight,
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(AppSpacing.navRadius),
            boxShadow: [
              // Comp: 0 12px 30px -12px rgba(0,0,0,.35). Flutter has no
              // spread-radius negative equivalent to CSS's, so the spread is
              // folded into a slightly tighter blur.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++) ...[
                // The add button sits in the middle of the run, matching the
                // comp's Home · Finance · [+] · Planner · Calendar order.
                if (onAdd != null && i == (destinations.length / 2).floor())
                  _AddButton(onTap: onAdd!, rotated: addMenuOpen),
                Expanded(
                  child: _NavButton(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    activeColor: colors.good,
                    inactiveColor: colors.text3,
                    onTap: () => onSelected(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre add button. Comp: 50px, radius 17, accent fill, `onAccent` plus,
/// and an accent glow (`0 8px 18px -6px accent`). The plus rotates to 135° over
/// 300ms while a sheet is open.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.rotated});

  final VoidCallback onTap;
  final bool rotated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tappable(
        onTap: onTap,
        haptic: TapHaptic.medium,
        semanticLabel: 'Add',
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: rotated ? AppMotion.fabRotationTurns : 0,
            duration: AppMotion.fabRotate,
            curve: AppMotion.emphasized,
            child: Icon(LucideIcons.plus, size: 26, color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// A single nav item. Icons 23px, labels 10px w700, accent when active and the
/// third text tone otherwise. The press response and its haptic come from
/// [Tappable], which carries the comp's universal `scale(.94)` behaviour.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;

    return Tappable(
      onTap: onTap,
      // The handoff's haptics map doesn't name tab switching; selection is the
      // closest listed intent (it covers segmented-control switches).
      haptic: TapHaptic.selection,
      semanticLabel: destination.label,
      selected: selected,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 23,
            color: color,
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
