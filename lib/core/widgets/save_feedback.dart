import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/haptics.dart';
import '../../features/calendar/presentation/widgets/calendar_save_wave.dart';
import '../../features/settings/application/settings_providers.dart';
import 'success_overlay.dart';

/// Delivers the user's chosen acknowledgement after a save or update succeeds.
Future<void> showSaveFeedback(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
}) => _deliver(
  context,
  ref.read(hapticsProvider),
  ref.read(settingsProvider),
  title: title,
  message: message,
);

/// [showSaveFeedback] for a flow that holds no `WidgetRef` — one opened from
/// a widget that may be gone by the time the save finishes, like the
/// sidebar's transfer dialog. Reads through [context]'s provider container.
Future<void> showSaveFeedbackIn(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return _deliver(
    context,
    container.read(hapticsProvider),
    container.read(settingsProvider),
    title: title,
    message: message,
  );
}

Future<void> _deliver(
  BuildContext context,
  LifeHaptics haptics,
  ResolvedSettings settings, {
  required String title,
  required String message,
}) {
  haptics.save();
  if (settings.saveConfirmationsEnabled) {
    return showSuccessOverlay(context, title: title, message: message);
  }
  if (settings.saveAnimationsEnabled) showSaveWave(context);
  return Future.value();
}

/// Marks a milestone worth more than a routine save — a habit streak, a goal
/// reached, a bill paid — with the same overlay but its own colourful emoji
/// in place of the plain tick.
///
/// Follows the same "save confirmations" setting as [showSaveFeedback]: a
/// milestone is still a confirmation, so someone who's turned those off
/// shouldn't get a bigger one instead. The save-wave fallback doesn't apply
/// here — it has no emoji slot, and a milestone is rare enough that skipping
/// it silently (bar the haptic) is the more honest "off" than a compromise.
Future<void> showCelebration(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required String emoji,
}) {
  ref.read(hapticsProvider).save();
  final settings = ref.read(settingsProvider);
  if (!settings.saveConfirmationsEnabled) return Future.value();
  return showSuccessOverlay(
    context,
    title: title,
    message: message,
    emoji: emoji,
  );
}
