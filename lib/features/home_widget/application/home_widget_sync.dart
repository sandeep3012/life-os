import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../habits/application/habits_providers.dart';
import '../../home/application/home_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/today_widget_snapshot.dart';

/// Where the snapshot goes. The real one writes to the Android widget; tests
/// swap in one that records what it was given.
abstract class HomeWidgetBridge {
  Future<void> push(Map<String, Object> data);
}

class _PlatformHomeWidgetBridge implements HomeWidgetBridge {
  /// The Kotlin provider class, fully qualified. Not the package-relative
  /// name: debug builds add `.dev` to the application id, and the plugin
  /// would look for the class under that.
  static const _androidClass = 'com.sandeep.lifeos.TodayWidgetProvider';

  @override
  Future<void> push(Map<String, Object> data) async {
    // Android only for now; elsewhere there's no widget to feed.
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidClass);
    } catch (_) {
      // A widget that can't update (plugin missing, no widget placed) must
      // never disturb the app.
    }
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => _PlatformHomeWidgetBridge(),
);

/// Keeps the home-screen widget in step with the app: whenever today's
/// tasks, habits, this month's spend or the privacy settings change, it
/// rebuilds the snapshot and pushes it — after a short pause, so a burst of
/// changes (a sync, sample data) is one update, and only when something the
/// widget shows actually changed.
class HomeWidgetSync {
  HomeWidgetSync(this._ref);

  final Ref _ref;
  Timer? _debounce;
  Map<String, Object>? _lastPushed;

  static const debounce = Duration(milliseconds: 800);

  void start() {
    _ref
      ..listen(todayTasksProvider, (_, _) => _schedule())
      ..listen(habitsWithProgressProvider, (_, _) => _schedule())
      ..listen(monthSpendMinorProvider, (_, _) => _schedule())
      ..listen(settingsProvider, (_, _) => _schedule());
    _schedule();
  }

  /// Pushes straight away — for the app coming back to the foreground on a
  /// new day, when nothing it listens to has changed but the date has.
  void refreshNow() {
    _debounce?.cancel();
    _push();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _push);
  }

  void _push() {
    final settings = _ref.read(settingsProvider);
    final data = TodayWidgetSnapshot.build(
      now: DateTime.now(),
      tasks: _ref.read(todayTasksProvider),
      habits: _ref.read(habitsWithProgressProvider),
      monthSpendMinor: _ref.read(monthSpendMinorProvider),
      currencyCode: settings.currencyCode,
      balancesVisible: settings.balancesVisible,
      appLocked: settings.appLockEnabled,
    ).toWidgetData();
    if (mapEquals(data, _lastPushed)) return;
    _lastPushed = data;
    _ref.read(homeWidgetBridgeProvider).push(data);
  }

  void dispose() => _debounce?.cancel();
}

final homeWidgetSyncProvider = Provider<HomeWidgetSync>((ref) {
  final sync = HomeWidgetSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
