import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell wrapping the 5 top-level tabs.
/// Each branch keeps its own navigation stack/state via [navigationShell].
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _exitConfirmationWindow = Duration(seconds: 2);
  DateTime? _lastExitAttempt;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Finance'),
    NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist_rounded), label: 'Tasks'),
    NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
    NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'More'),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          destinations: _destinations,
          onDestinationSelected: (index) => widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
        ),
      ),
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
