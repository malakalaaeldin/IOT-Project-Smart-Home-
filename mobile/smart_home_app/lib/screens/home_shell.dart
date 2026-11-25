import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/home_state.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/state_views.dart';
import 'automation_screen.dart';
import 'controls_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// The signed-in app: bottom navigation between the five screens, the
/// no-internet banner, and alert notifications.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user, required this.auth, required this.theme});
  final User user;
  final AuthService auth;
  final ThemeService theme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final AppServices _s = AppServices(auth: widget.auth, theme: widget.theme);
  int _tab = 0;
  AppUser? _me;
  bool _showOffline = false;
  Timer? _offlineTimer;
  bool _inForeground = true;
  bool? _lastFire;
  bool? _lastRain;
  final List<StreamSubscription<dynamic>> _subs = [];

  static const _titles = ['Dashboard', 'Controls', 'Automation', 'History', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s.users.ensureRecord(widget.user);
    _subs.add(_s.users.watch(widget.user).listen((u) {
      if (mounted) setState(() => _me = u);
    }));
    // Only show "no internet" if it lasts more than 3 s (avoids a flash at start).
    _subs.add(_s.home.connected.listen((ok) {
      _offlineTimer?.cancel();
      if (ok) {
        if (_showOffline && mounted) setState(() => _showOffline = false);
      } else {
        _offlineTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showOffline = true);
        });
      }
    }));
    _subs.add(_s.home.state.listen(_watchAlerts));
    _s.notifications.init().then((_) {
      final token = _s.notifications.token;
      if (token != null) _s.users.saveFcmToken(widget.user.uid, token);
      if (mounted) setState(() {});
    });
  }

  /// Shows a notification when fire or rain starts while the app is open.
  /// (When the app is closed, the Cloud Function's push does this.)
  void _watchAlerts(HomeState s) {
    final fire = s.fire.detected;
    final rain = s.clothesLine.raining;
    if (_inForeground) {
      if (fire && _lastFire != true) {
        _s.notifications.show(NotificationService.idFire, '🔥 Fire detected!',
            'The flame sensor detected fire. Open the app to silence the alarm.');
      }
      if (rain && _lastRain != true) {
        _s.notifications.show(NotificationService.idRain, "🌧 It's raining",
            'The clothes line is closing automatically.');
      }
    }
    _lastFire = fire;
    _lastRain = rain;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _me?.isAdmin == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          if (isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(label: Text('Admin'), visualDensity: VisualDensity.compact),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showOffline) const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                DashboardScreen(services: _s),
                ControlsScreen(services: _s),
                AutomationScreen(services: _s, isAdmin: isAdmin),
                HistoryScreen(services: _s),
                SettingsScreen(services: _s, me: _me),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.toggle_off_outlined), selectedIcon: Icon(Icons.toggle_on), label: 'Controls'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Automation'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
