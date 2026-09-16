import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../../features/habits/application/habits_providers.dart';
import '../../features/finance/presentation/widgets/transfer_money_dialog.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../core/widgets/tappable.dart';

/// The design's sidebar drawer: 290px wide, `bg` background, a 1px hairline down
/// its trailing edge, a gradient-avatar header, a list of destinations with the
/// active one in `accentSoft`/`accentInk`, and a light/dark toggle pinned to the
/// footer.
///
/// This is where the comp retires the old "More" tab to. Destinations are
/// grouped by the top-level area they belong to, while live counts continue to
/// come from real providers rather than fixed numbers.
///
/// The comp's "Gym Planner" and "Investments" rows are deliberately absent: this
/// build has no workout module, and adding a row that navigates nowhere is worse
/// than omitting it until the feature exists.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final habitCount = ref.watch(habitsWithProgressProvider).length;
    final openTodoCount = (ref.watch(allTasksProvider).value ?? const [])
        .where((t) => t.status != 'done')
        .length;

    final settings = ref.watch(settingsProvider);
    final isDark =
        settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final current = GoRouterState.of(context).uri.toString();

    return Drawer(
      width: 290,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: Border(right: BorderSide(color: scheme.outline)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.heroA, colors.heroB],
                      ),
                    ),
                    child: Icon(
                      LucideIcons.user,
                      size: 22,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LifeOS',
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'On this device',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12,
                            color: colors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _SidebarGroup(
                    key: const ValueKey('finance'),
                    title: 'Finance',
                    children: [
                      _Item(
                        icon: LucideIcons.chartPie,
                        label: 'Finance home',
                        path: RoutePaths.finance,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.receipt,
                        label: 'Bills',
                        path: RoutePaths.bills,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.refreshCw,
                        label: 'Recurring transactions',
                        path: RoutePaths.recurringTransactions,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.arrowLeftRight,
                        label: 'Transfer money',
                        path: RoutePaths.finance,
                        current: current,
                        activeOverride: false,
                        onTap: () {
                          final hostContext = Navigator.of(
                            context,
                            rootNavigator: true,
                          ).context;
                          Navigator.of(context).pop();
                          Future.microtask(() {
                            if (!hostContext.mounted) return;
                            showTransferMoneyDialog(hostContext, ref);
                          });
                        },
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('financial-insights'),
                    title: 'Financial insights',
                    children: [
                      _Item(
                        icon: LucideIcons.chartLine,
                        label: 'Spend analyser',
                        path: RoutePaths.spendAnalyzer,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.trendingUp,
                        label: 'Net worth',
                        path: RoutePaths.netWorth,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.fileBarChart,
                        label: 'Reports',
                        path: RoutePaths.reports,
                        current: current,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('planner'),
                    title: 'Planner',
                    children: [
                      _Item(
                        icon: LucideIcons.listChecks,
                        label: 'Tasks',
                        path: RoutePaths.tasksHabits,
                        current: current,
                        count: openTodoCount,
                      ),
                      _Item(
                        icon: LucideIcons.repeat,
                        label: 'Habits',
                        path: RoutePaths.plannerHabits,
                        current: current,
                        count: habitCount,
                      ),
                      _Item(
                        icon: LucideIcons.flag,
                        label: 'Goals',
                        path: RoutePaths.goals,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.calendar,
                        label: 'Calendar',
                        path: RoutePaths.calendar,
                        current: current,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('workspace'),
                    title: 'Workspace',
                    children: [
                      _Item(
                        icon: LucideIcons.search,
                        label: 'Global search',
                        path: RoutePaths.search,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.fileText,
                        label: 'Notes',
                        path: RoutePaths.notes,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.folder,
                        label: 'Documents',
                        path: RoutePaths.documents,
                        current: current,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('growth'),
                    title: 'Growth',
                    children: [
                      _Item(
                        icon: LucideIcons.heart,
                        label: 'Health',
                        path: RoutePaths.health,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.bookOpen,
                        label: 'Learn',
                        path: RoutePaths.learn,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.sparkles,
                        label: 'AI analyser',
                        path: RoutePaths.aiAnalyser,
                        current: current,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('app'),
                    title: 'App',
                    children: [
                      _Item(
                        icon: LucideIcons.cloud,
                        label: 'Sync & account',
                        path: RoutePaths.syncSignIn,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.settings,
                        label: 'Settings',
                        path: RoutePaths.settings,
                        current: current,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    key: const ValueKey('extra'),
                    title: 'Extra',
                    children: [
                      _Item(
                        icon: LucideIcons.chartLine,
                        label: 'Finance overview',
                        path: RoutePaths.financeOverview,
                        current: current,
                      ),
                      _Item(
                        icon: LucideIcons.repeat,
                        label: 'Habits overview',
                        path: RoutePaths.habitsOverview,
                        current: current,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 14),
              child: Row(
                children: [
                  Icon(
                    isDark ? LucideIcons.moon : LucideIcons.sun,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isDark ? 'Dark mode' : 'Light mode',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (value) {
                      ref
                          .read(settingsControllerProvider)
                          .setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
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

class _SidebarGroup extends StatefulWidget {
  const _SidebarGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  State<_SidebarGroup> createState() => _SidebarGroupState();
}

class _SidebarGroupState extends State<_SidebarGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Tappable(
            onTap: () => setState(() => _expanded = !_expanded),
            semanticLabel:
                '${_expanded ? 'Collapse' : 'Expand'} ${widget.title}',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: colors.accentInk,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: _expanded ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Column(children: widget.children),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.path,
    required this.current,
    this.count,
    this.onTap,
    this.activeOverride,
  });

  final IconData icon;
  final String label;
  final String path;
  final String current;
  final int? count;
  final VoidCallback? onTap;
  final bool? activeOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final active = activeOverride ?? current == path;
    final ink = active ? colors.accentInk : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tappable(
        haptic: TapHaptic.light,
        semanticLabel: label,
        selected: active,
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          Navigator.of(context).pop();
          if (!active) context.go(path);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.accentInk,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
