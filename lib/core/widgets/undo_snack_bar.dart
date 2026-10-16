import 'package:flutter/material.dart';

/// How long an Undo is offered after a delete.
const undoWindow = Duration(seconds: 5);

/// "Task deleted · Undo" — shown on the app's messenger, so it stays up
/// even when the delete closed the screen it was made on.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required Future<void> Function() onUndo,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: undoWindow,
        // A snackbar with an action stays until tapped unless told
        // otherwise; Undo is only on offer for [undoWindow].
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Undo', onPressed: () => onUndo()),
      ),
    );
}
