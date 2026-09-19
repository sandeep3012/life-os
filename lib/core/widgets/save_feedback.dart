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
