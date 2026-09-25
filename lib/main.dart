import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_restart.dart';
import 'app/splash_gate.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // The native splash stays up until LifeOSApp's first screen has its data.
  SplashGate.hold(binding);
  runApp(const AppRestartBoundary(child: ProviderScope(child: LifeOSApp())));
}
