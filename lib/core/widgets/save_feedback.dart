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
}) {
  ref.read(hapticsProvider).save();
  final settings = ref.read(settingsProvider);
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
