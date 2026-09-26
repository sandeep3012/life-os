import 'package:flutter/foundation.dart';

/// Milestones of a cold start, printed as milliseconds since `main`.
///
/// Launch time depends on things tests can't reproduce — a debug build's JIT,
/// the database running on a background isolate, a real device's I/O — so
/// this is what tells where a slow launch actually spends its time. Silent in
/// release builds.
abstract final class LaunchTimeline {
  static final _clock = Stopwatch();
  static final _seen = <String>{};

  static void start() {
    _clock.start();
    mark('main');
  }

  /// Logs [event] once per process; later calls with the same name are
  /// ignored, so marks placed in `build` don't repeat on every rebuild.
  static void mark(String event) {
    if (kReleaseMode || !_seen.add(event)) return;
    debugPrint('[launch] ${_clock.elapsedMilliseconds}ms  $event');
  }
}
