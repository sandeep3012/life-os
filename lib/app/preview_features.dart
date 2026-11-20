import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the parts of the app that are built but not yet tested enough to
/// ship are shown: the Health and Learn modules, and the side menu's
/// "Extra" section.
///
/// On in debug builds, off in release (and profile) builds. Nothing is
/// removed — the screens and their data stay; only the ways in are hidden —
/// so turning a module on for everyone is deleting its check here.
final previewFeaturesProvider = Provider<bool>((ref) => kDebugMode);
