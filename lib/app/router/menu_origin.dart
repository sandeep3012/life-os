import 'route_paths.dart';

/// Which bottom-nav tab is showing, so a side-menu screen can open on top of
/// it. [AppShell] keeps it current.
abstract final class MenuOrigin {
  static const _roots = [
    RoutePaths.home,
    RoutePaths.finance,
    RoutePaths.tasksHabits,
    RoutePaths.calendar,
  ];

  static String tabRoot = RoutePaths.home;

  static void showing(int tabIndex) =>
      tabRoot = _roots[tabIndex.clamp(0, _roots.length - 1)];

  /// `/finance/more/notes` as callers and the side menu know it:
  /// `/more/notes`. Anything else comes back unchanged.
  static String plain(String location) {
    for (final root in _roots) {
      if (location.startsWith('$root${RoutePaths.more}/')) {
        return location.substring(root.length);
      }
    }
    return location;
  }
}
