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
