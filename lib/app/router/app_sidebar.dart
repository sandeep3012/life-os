import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../../features/habits/application/habits_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../core/widgets/tappable.dart';

/// The design's sidebar drawer: 290px wide, `bg` background, a 1px hairline down
/// its trailing edge, a gradient-avatar header, a list of destinations with the
/// active one in `accentSoft`/`accentInk`, and a light/dark toggle pinned to the
/// footer.
///
/// This is where the comp retires the old "More" tab to — every destination that
/// used to live behind it is a row here. Two rows carry live counts, as the comp
/// specifies (`Habits (4)`, `To-dos & Reminders (2)`); those come from real
/// providers, not fixed numbers.
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
    final isDark = settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final current = GoRouterState.of(context).uri.path;

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
                  _Item(
                    icon: LucideIcons.layoutDashboard,
                    label: 'Home',
                    path: RoutePaths.home,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.wallet,
                    label: 'Finance',
                    path: RoutePaths.finance,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.chartPie,
                    label: 'Budgets & ledger',
                    path: RoutePaths.financeLedger,
                    current: current,
                  ),
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
                    icon: LucideIcons.refreshCw,
                    label: 'Recurring',
                    path: RoutePaths.recurringTransactions,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.receipt,
                    label: 'Bills',
                    path: RoutePaths.bills,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.repeat,
                    label: 'Habits',
                    path: RoutePaths.habitsOverview,
                    current: current,
                    count: habitCount,
                  ),
                  _Item(
                    icon: LucideIcons.listChecks,
                    label: 'To-dos & reminders',
                    path: RoutePaths.tasksHabits,
                    current: current,
                    count: openTodoCount,
                  ),
                  _Item(
                    icon: LucideIcons.heart,
                    label: 'Health',
                    path: RoutePaths.health,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.calendar,
                    label: 'Calendar',
                    path: RoutePaths.calendar,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.bookOpen,
                    label: 'Learn',
                    path: RoutePaths.learn,
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
                  _Item(
                    icon: LucideIcons.flag,
                    label: 'Goals',
                    path: RoutePaths.goals,
                    current: current,
                  ),
                  _Item(
                    icon: LucideIcons.sparkles,
                    label: 'Insights',
                    path: RoutePaths.aiAnalyser,
                    current: current,
                  ),
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
                          .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
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

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.path,
    required this.current,
    this.count,
  });

  final IconData icon;
  final String label;
  final String path;
  final String current;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final active = current == path;
    final ink = active ? colors.accentInk : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tappable(
        haptic: TapHaptic.light,
        semanticLabel: label,
        selected: active,
        onTap: () {
          Navigator.of(context).pop();
          if (!active) context.go(path);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
