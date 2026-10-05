import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/currency_utils.dart';
import '../../core/widgets/save_feedback.dart';
import '../../core/widgets/tappable.dart';
import '../../features/finance/application/finance_providers.dart';
import '../../features/finance/presentation/widgets/entry_form_sheet.dart';
import '../../features/finance/presentation/widgets/quick_add_account_sheet.dart';
import '../../features/finance/presentation/widgets/transaction_recorder_sheet.dart';
import '../../features/finance/presentation/widgets/transaction_save_confirmation.dart';
import '../../features/goals/application/goals_providers.dart';
import '../../features/goals/presentation/widgets/quick_add_goal_sheet.dart';
import '../../features/habits/application/habits_providers.dart';
import '../../features/habits/presentation/widgets/quick_add_habit_sheet.dart';
import '../../features/home/presentation/widgets/add_menu_sheet.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/presentation/widgets/quick_add_task_sheet.dart';
import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'navigator_keys.dart';
import '../../features/onboarding/application/onboarding_gate.dart';

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
    AppNavDestination(
      LucideIcons.layoutDashboard,
      LucideIcons.layoutDashboard,
      'Home',
    ),
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

  /// The comp's six tiles, mapped onto the six things this build can create.
  /// Investment and Recurring SIP are gone — there is no investments module,
  /// and recurring entries have their own sheet reached from Finance — so the
  /// slots go to the planner and goals flows instead.
  ///
  /// Every tile opens the module's own quick-add sheet and saves through that
  /// module's controller; none of them navigate away, so the menu can be used
  /// from any tab without losing your place.
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
          onTap: () => _addTransaction(EntryKind.expense),
        ),
        AddMenuItem(
          label: 'Income',
          subtitle: 'Salary, refunds',
          icon: LucideIcons.arrowUpRight,
          color: colors.finance,
          onTap: () => _addTransaction(EntryKind.income),
        ),
        AddMenuItem(
          label: 'Habit',
          subtitle: 'Build a routine',
          icon: LucideIcons.sprout,
          color: colors.habits,
          onTap: _addHabit,
        ),
        AddMenuItem(
          label: 'Task',
          subtitle: 'Something to do',
          icon: LucideIcons.circleCheckBig,
          color: colors.tasks,
          onTap: _addTask,
        ),
        AddMenuItem(
          label: 'Goal',
          subtitle: 'Track progress',
          icon: LucideIcons.target,
          color: colors.goals,
          onTap: _addGoal,
        ),
        AddMenuItem(
          label: 'Account',
          subtitle: 'Bank, card, cash',
          icon: LucideIcons.landmark,
          color: colors.finance,
          onTap: _addAccount,
        ),
      ],
    );

    if (mounted) setState(() => _addMenuOpen = false);
  }

  /// The shell watches none of these streams, and Riverpod tears an unlistened
  /// [StreamProvider] down before its first emission ever arrives — so hold a
  /// subscription for the duration of the await.
  Future<List<T>> _readList<T>(StreamProvider<List<T>> provider) async {
    final cached = ref.read(provider).value;
    if (cached != null) return cached;
    final subscription = ref.listenManual(provider, (_, _) {});
    try {
      return await ref.read(provider.future);
    } finally {
      subscription.close();
    }
  }

  /// The menu's sheets open on the active branch's navigator, like the
  /// transaction recorder does, so they sit above the floating nav bar.
  BuildContext get _sheetContext =>
      branchNavigatorKeys[widget.navigationShell.currentIndex].currentContext ??
      context;

  Future<void> _addHabit() async {
    final categories = await _readList(habitCategoriesProvider);
    if (!mounted) return;
    final result = await showQuickAddHabitSheet(
      _sheetContext,
      categories: categories,
    );
    if (result == null) return;
    await ref
        .read(habitsControllerProvider)
        .addHabit(
          result.name,
          targetAmount: result.targetAmount,
          targetUnit: result.targetUnit,
          description: result.description,
          schedule: result.schedule,
          categoryId: result.categoryId,
          reminderEnabled: result.reminderEnabled,
          reminderHour: result.reminderHour,
          reminderMinute: result.reminderMinute,
          reminderMode: result.reminderMode,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Habit saved',
      message: '“${result.name}” is ready to track.',
    );
  }

  Future<void> _addTask() async {
    final result = await showQuickAddTaskSheet(_sheetContext);
    if (result == null) return;
    await ref
        .read(tasksControllerProvider)
        .addTask(
          title: result.title,
          description: result.description,
          categoryId: result.categoryId,
          schedule: result.schedule,
          priority: result.priority,
          dueDate: result.dueDate,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Task saved',
      message: '“${result.title}” is ready to do.',
    );
  }

  Future<void> _addGoal() async {
    final habits = (await _readList(
      goalHabitsProvider,
    )).where((habit) => !habit.archived).toList();
    if (!mounted) return;
    final accounts = ref.read(activeAccountsProvider);
    final result = await showQuickAddGoalSheet(
      _sheetContext,
      habits: habits,
      accounts: accounts,
      currencySymbol: currencySymbolFor(
        ref.read(settingsProvider).currencyCode,
      ),
    );
    if (result == null) return;
    final goalId = await ref
        .read(goalsControllerProvider)
        .createGoal(
          title: result.title,
          type: result.type,
          targetValue: result.targetValue,
          targetDate: result.targetDate,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
          reminderDaysBefore: result.reminderDaysBefore,
        );
    if (result.link != null) {
      await ref
          .read(goalsControllerProvider)
          .addLink(
            goalId: goalId,
            linkedType: result.link!.type,
            linkedId: result.link!.id,
          );
    }
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Goal saved',
      message: '“${result.title}” is being tracked.',
    );
  }

  Future<void> _addAccount() async {
    final accountTypes = await _readList(accountTypesProvider);
    if (!mounted) return;
    final result = await showQuickAddAccountSheet(
      _sheetContext,
      accountTypes: accountTypes,
      currencySymbol: currencySymbolFor(
        ref.read(settingsProvider).currencyCode,
      ),
    );
    if (result == null) return;
    await ref
        .read(financeControllerProvider)
        .addAccount(
          name: result.name,
          type: result.type,
          balanceMinor: result.startingBalanceMinor,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Account saved',
      message: '“${result.name}” is ready to use.',
    );
  }

  /// Opens the design's keypad entry sheet, then persists through the finance
  /// module's existing controller rather than duplicating the save path here.
  Future<void> _addTransaction(EntryKind kind) async {
    final accounts = ref.read(transactableAccountsProvider);
    final categories = ref.read(categoriesProvider).value ?? const [];
    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add an account first')));
      return;
    }

    final result = await showTransactionRecorder(
      branchNavigatorKeys[widget.navigationShell.currentIndex].currentContext ??
          context,
      ref,
      accounts: accounts,
      categories: categories,
      initialKind: kind,
      currencySymbol: currencySymbolFor(
        ref.read(settingsProvider).currencyCode,
      ),
    );
    if (result == null) return;
    await ref
        .read(financeControllerProvider)
        .addTransaction(
          accountId: result.accountId,
          categoryId: result.categoryId,
          merchant: result.merchant,
          amountMinor: result.amountMinor,
          date: result.date,
        );

    if (!mounted) return;
    await showTransactionSaveConfirmation(
      context,
      ref: ref,
      result: result,
      accounts: accounts,
      currencyCode: ref.read(settingsProvider).currencyCode,
    );
  }

  void _handleSystemBack(bool didPop) {
    if (didPop || Theme.of(context).platform != TargetPlatform.android) return;

    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }

    final now = DateTime.now();
    if (_lastExitAttempt != null &&
        now.difference(_lastExitAttempt!) <= _exitConfirmationWindow) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Mirrors the Row below: the add button (50 + 6 either side)
              // takes its slice out of the middle, and the destinations share
              // the rest equally — so each tab's centre is known without
              // measuring, which is what lets the highlight slide between them.
              final addWidth = onAdd == null ? 0.0 : _AddButton.slotWidth;
              final itemWidth =
                  (constraints.maxWidth - addWidth) / destinations.length;
              final addAt = (destinations.length / 2).floor();
              double centreOf(int i) =>
                  (onAdd != null && i >= addAt ? addWidth : 0) +
                  i * itemWidth +
                  itemWidth / 2;

              return Stack(
                children: [
                  _NavHighlight(
                    index: selectedIndex,
                    centre: centreOf(selectedIndex),
                    top:
                        _NavButton.iconCentreY(constraints.maxHeight) -
                        _NavHighlight.height / 2,
                    color: colors.accentSoft,
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++) ...[
                        // The add button sits in the middle of the run,
                        // matching the comp's Home · Finance · [+] · Planner ·
                        // Calendar order.
                        if (onAdd != null && i == addAt)
                          _AddButton(onTap: onAdd!, rotated: addMenuOpen),
                        Expanded(
                          child: _NavButton(
                            destination: destinations[i],
                            selected: i == selectedIndex,
                            activeColor: scheme.primary,
                            inactiveColor: colors.text3,
                            onTap: () => onSelected(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The soft capsule behind the selected tab's icon.
///
/// On a tab change it *stretches*: the edge facing the new tab sets off first
/// and the trailing edge follows a beat later, so the capsule lengthens across
/// the gap and then contracts onto the destination instead of sliding as a
/// rigid block. A resize or a first build snaps without animating — only a
/// change of [index] is a tab change.
class _NavHighlight extends StatefulWidget {
  const _NavHighlight({
    required this.index,
    required this.centre,
    required this.top,
    required this.color,
  });

  static const double width = 44;
  static const double height = 28;

  /// Which tab is selected; a change here (not of [centre]) triggers the
  /// stretch.
  final int index;

  /// The selected tab's horizontal centre, in the bar's own coordinates.
  final double centre;
  final double top;
  final Color color;

  @override
  State<_NavHighlight> createState() => _NavHighlightState();
}

class _NavHighlightState extends State<_NavHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.navSwitch,
    value: 1,
  );
  late double _from = widget.centre;
  late double _to = widget.centre;

  @override
  void didUpdateWidget(_NavHighlight old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      // Start from wherever the capsule currently is, so a second tap
      // mid-flight redirects it rather than jumping back to the old tab.
      final (left, right) = _edgesAt(
        _controller.value,
        MediaQuery.of(context).disableAnimations,
      );
      _from = (left + right) / 2;
      _to = widget.centre;
      _controller.duration = AppMotion.of(context, AppMotion.navSwitch);
      _controller.forward(from: 0);
    } else if (widget.centre != old.centre) {
      _from = _to = widget.centre;
      _controller.value = 1;
    }
  }

  /// The capsule's left and right edges at animation time [t]. The edge facing
  /// the destination leads and the other trails, which is the stretch.
  (double, double) _edgesAt(double t, bool reduced) {
    final lead = reduced
        ? Curves.linear
        : const Interval(0, 0.65, curve: AppMotion.emphasized);
    final trail = reduced
        ? Curves.linear
        : const Interval(0.2, 1, curve: AppMotion.emphasized);
    const half = _NavHighlight.width / 2;
    final movingRight = _to >= _from;
    final leftT = (movingRight ? trail : lead).transform(t);
    final rightT = (movingRight ? lead : trail).transform(t);
    return (
      (_from - half) + ((_to - half) - (_from - half)) * leftT,
      (_from + half) + ((_to + half) - (_from + half)) * rightT,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    return Positioned.fill(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final (left, right) = _edgesAt(_controller.value, reduced);

              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: widget.top,
                    width: right - left,
                    height: _NavHighlight.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(
                          _NavHighlight.height / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The centre add button. Comp: 50px, radius 17, accent fill, `onAccent` plus.
/// The plus rotates to 135° over 300ms while a sheet is open.
///
/// Deliberately flat: the comp's accent glow (`0 8px 18px -6px accent`) tinted
/// the shadow with the accent itself, which reads as a coloured smudge under
/// the button on every palette rather than as depth. The app's other
/// `FloatingActionButton`s are `elevation: 0` at the same radius 17
/// (`AppTheme.floatingActionButtonTheme`), so this matches them.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.rotated});

  /// The button's 50px plus the 6px of padding either side — the width it takes
  /// out of the bar, which the tab highlight needs to find each tab's centre.
  static const double slotWidth = 62;

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
          key: TourTargets.addButton,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(17),
          ),
          child: AnimatedRotation(
            turns: rotated ? AppMotion.fabRotationTurns : 0,
            duration: AppMotion.of(context, AppMotion.fabRotate),
            curve: AppMotion.curveOf(context, AppMotion.emphasized),
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
///
/// Becoming selected pops the icon (dips, overshoots, settles) and cross-fades
/// the icon and label colour, in step with the highlight arriving behind it.
class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  /// Icon (23) + gap (3) + a 10px label's line, as laid out below.
  static const double _contentHeight = 39;

  /// Where the icon's centre sits vertically in a bar [barHeight] tall — the
  /// column is centred, so the highlight uses this to sit behind the icon.
  static double iconCentreY(double barHeight) =>
      (barHeight - _contentHeight) / 2 + 23 / 2;

  final AppNavDestination destination;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppMotion.navSwitch,
    value: 1,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.8,
        end: 1.16,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.16,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
  ]);
  static final _lift = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 3.0,
        end: -3.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -3.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
  ]);

  @override
  void didUpdateWidget(_NavButton old) {
    super.didUpdateWidget(old);
    if (widget.selected &&
        !old.selected &&
        !MediaQuery.of(context).disableAnimations) {
      _pop.duration = AppMotion.navSwitch;
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.activeColor : widget.inactiveColor;
    final fade = AppMotion.of(context, AppMotion.navColor);

    return Tappable(
      onTap: widget.onTap,
      // The handoff's haptics map doesn't name tab switching; selection is the
      // closest listed intent (it covers segmented-control switches).
      haptic: TapHaptic.selection,
      semanticLabel: widget.destination.label,
      selected: widget.selected,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: fade,
        builder: (context, animated, _) {
          final tint = animated ?? color;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pop,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _lift.evaluate(_pop)),
                  child: Transform.scale(
                    scale: _scale.evaluate(_pop),
                    child: child,
                  ),
                ),
                child: Icon(
                  widget.selected
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  size: 23,
                  color: tint,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.destination.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
