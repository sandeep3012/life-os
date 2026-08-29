import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] so every interaction in the app
/// uses a consistent feedback strength for a given action type.
class AppHaptics {
  const AppHaptics._();

  /// Toggling something on/off — completing a task, checking off a habit.
  static void toggle() => HapticFeedback.lightImpact();

  /// Destructive actions — delete, swipe-to-dismiss.
  static void delete() => HapticFeedback.mediumImpact();

  /// A save/create action succeeded.
  static void success() => HapticFeedback.lightImpact();
}
