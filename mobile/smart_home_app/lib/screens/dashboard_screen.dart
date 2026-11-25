import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_alert.dart';
import '../models/home_state.dart';
import '../models/module_info.dart';
import '../services/app_services.dart';
import '../widgets/alert_tile.dart';
import '../widgets/format.dart';
import '../widgets/module_card.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';
import '../widgets/chat_panel.dart';

/// Live dashboard: ESP32 status, alerts, the chat assistant and every module.
/// Updates automatically from Firebase (no refresh button).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<HomeState> _state = widget.services.home.state;
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Re-evaluate online/offline even when no new data arrives.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.services.home;
    return StreamBuilder<HomeState>(
      stream: _state,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final s = snap.data!;
        if (s.isEmpty) {
          return const MessageView(
            icon: Icons.sensors_off,
            title: 'No data from the house yet',
            message: 'Power on the ESP32. Readings appear here as soon as it connects.',
          );
        }
        final live = home.liveness(s);
        final alerts = HomeAlert.from(s, live);
        final seen = home.lastSeen(s);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  live == Liveness.online ? Icons.cloud_done : Icons.cloud_off,
                  color: live == Liveness.online ? Colors.green : Colors.orange,
                  size: 32,
                ),
                title: const Text('ESP32 hub'),
                subtitle: Text([
                  if (s.status.wifiRssi != null) 'Wi-Fi ${s.status.wifiRssi} dBm',
                  if (seen != null) 'last seen ${timeAgo(seen, now: home.serverNow)}',
                ].join(' · ')),
                trailing: StatusChip(liveness: live),
              ),
            ),
            const SizedBox(height: 8),
            Text('Alerts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              const AlertTile(
                alert: HomeAlert(AlertLevel.info, 'All clear', 'No fire, no rain, the board is online.'),
              )
            else
              for (final a in alerts)
                AlertTile(
                  alert: a,
                  action: a.id == 'fire' && s.fire.buzzerOn
                      ? FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => home.sendCommands({'silenceBuzzer': true}),
                          child: const Text('Silence'),
                        )
                      : null,
                ),
            const SizedBox(height: 8),
            ChatPanel(agent: widget.services.chat),
            const SizedBox(height: 16),
            Text('Modules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _summary(ModuleInfo.garage, live,
                '${s.garage.open ? 'Open' : 'Closed'} · ${cm(s.garage.distanceCm)} · auto ${s.garage.autoMode ? 'on' : 'off'}'),
            _summary(ModuleInfo.clothesLine, live,
                '${s.clothesLine.open ? 'Open' : 'Closed'} · ${s.clothesLine.raining ? 'Raining' : 'Dry'}'),
            _summary(ModuleInfo.fireAlarm, live,
                s.fire.detected
                    ? 'FIRE · buzzer ${s.fire.buzzerOn ? 'on' : 'silenced'}'
                    : 'No flame · buzzer off',
                danger: s.fire.detected),
            _summary(ModuleInfo.fan, live, s.fanOn ? 'On' : 'Off'),
            _summary(ModuleInfo.lights, live, '${s.lightsOn} of 3 on'),
          ],
        );
      },
    );
  }

  Widget _summary(ModuleInfo m, Liveness live, String reading, {bool danger = false}) =>
      ModuleCard(
        module: m,
        liveness: live,
        highlight: danger ? Colors.red.withValues(alpha: 0.12) : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 34, bottom: 6),
          child: Text(reading,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: danger ? Colors.red : null,
                  )),
        ),
      );
}
