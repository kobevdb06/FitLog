import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/security/biometric_service.dart';
import 'core/util/notification_service.dart';
import 'features/workout/panel/panel_bridge.dart';
import 'features/workout/panel/workout_panel_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is Dutch-only for this release.
  Intl.defaultLocale = 'nl';
  await initializeDateFormatting('nl');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await NotificationService.instance.initialise();

  runApp(const ProviderScope(child: FitLogApp()));
}

/// The panel over another app, from Aanpassen or Coach in the workout
/// notification: its own engine, started by `WorkoutPanelActivity`. It opens
/// no database and needs no plugin set up - the running app does that part.
@pragma('vm:entry-point')
Future<void> panelMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nl';
  await initializeDateFormatting('nl');
  runApp(
    WorkoutPanelApp(
      bridge: AndroidPanelBridge(),
      biometrics: BiometricService(),
    ),
  );
}
