import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_restart.dart';
import 'app/launch_timeline.dart';
import 'app/splash_gate.dart';
import 'app/transitions/screen_reveal.dart';
import 'features/sync/data/supabase_config.dart';

Future<void> main() async {
  LaunchTimeline.start();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // The native splash stays up until LifeOSApp's first screen has its data.
  SplashGate.hold(binding);
  // Only in a build with sync's key. It reads the saved session from disk
  // and makes no network call, so launch isn't held up waiting on one.
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    } on Object {
      // The app is fully usable without sync; it just stays local.
    }
  }
  runApp(
    const ScreenReveal(
      child: AppRestartBoundary(child: ProviderScope(child: LifeOSApp())),
    ),
  );
}
