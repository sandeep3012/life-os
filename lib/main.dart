import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_restart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRestartBoundary(child: ProviderScope(child: LifeOSApp())));
}
