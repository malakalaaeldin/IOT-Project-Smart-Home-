/*
 * Calm Hills Smart Home — Flutter app
 * Team: see lib/config/team.dart (each module's card shows who built it).
 *
 * Structure:
 *   screens/   one file per screen (login, dashboard, controls, automation, history, settings)
 *   models/    typed data (house state, settings, schedules, history, users, alerts)
 *   widgets/   reusable UI (module card, status chip, charts, loading/error views, chat panel)
 *   services/  ALL Firebase + platform logic (auth, database, users, notifications, theme, chat assistant)
 */
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';

/// Push messages that arrive while the app is closed are shown by Android
/// automatically; this handler only has to exist (and initialise Firebase).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // The native plugin may already have created the [DEFAULT] app.
    debugPrint('Firebase already initialized: $e');
  }
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  final theme = ThemeService();
  await theme.load();
  runApp(SmartHomeApp(theme: theme, auth: AuthService()));
}
