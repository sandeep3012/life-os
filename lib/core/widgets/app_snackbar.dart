import 'package:flutter/material.dart';

/// Shows a SnackBar styled consistently with the app's rounded, floating
/// card language, instead of the stock Material bar. Use in place of
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` wherever the
/// message is a simple confirmation/undo, so every screen looks the same.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}
