import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/application/home_providers.dart';

/// Bottom-nav shell wrapping the 5 top-level tabs.
/// Each branch keeps its own navigation stack/state via [navigationShell].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingTasks = ref.watch(todayTasksProvider).remaining;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Finance',
      ),
      NavigationDestination(
        icon: remainingTasks > 0
            ? Badge(label: Text('$remainingTasks'), child: const Icon(Icons.checklist_outlined))
            : const Icon(Icons.checklist_outlined),
        selectedIcon: remainingTasks > 0
            ? Badge(label: Text('$remainingTasks'), child: const Icon(Icons.checklist_rounded))
            : const Icon(Icons.checklist_rounded),
        label: 'Tasks',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Calendar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'More',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
