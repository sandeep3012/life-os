import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens parts of the phone's own settings for this app.
abstract final class SystemSettings {
  static const _channel = MethodChannel('com.sandeep.lifeos/system');

  /// Whether [openNotificationSettings] has somewhere to go. Android only:
  /// iOS has no per-app sound settings to open.
  static bool get canOpenNotificationSettings =>
      !kIsWeb && Platform.isAndroid;

  /// After an alarm is snoozed or dismissed over the lock screen: sends the
  /// app to the background so the phone shows its lock screen again. Does
  /// nothing when the phone is unlocked, where the person stays in the app.
  static Future<void> leaveIfLocked() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('leaveIfLocked');
    } catch (_) {
      // Only tidies up after the alarm; never worth failing over.
    }
  }

  /// Android's notification settings for LifeOS — each reminder type's
  /// channel, with its sound. Returns whether it opened.
  static Future<bool> openNotificationSettings() async {
    if (!canOpenNotificationSettings) return false;
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
