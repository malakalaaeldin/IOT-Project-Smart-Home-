import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'widgets/state_views.dart';

/// Root widget: light/dark themes and the login gate.
class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key, required this.theme, required this.auth});
  final ThemeService theme;
  final AuthService auth;

  static const _seed = Color(0xFF0F6B4C);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp(
        title: 'Calm Hills Smart Home',
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: _AuthGate(auth: auth, theme: theme),
      ),
    );
  }
}

/// Only signed-in users see the house (project requirement).
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.auth, required this.theme});
  final AuthService auth;
  final ThemeService theme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView(message: 'Starting…'));
        }
        final user = snap.data;
        if (user == null) return LoginScreen(auth: auth);
        // A new key per user rebuilds all services for each login.
        return HomeShell(key: ValueKey(user.uid), user: user, auth: auth, theme: theme);
      },
    );
  }
}
