import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_state.dart';
import '../models/module_info.dart';
import '../models/pending_commands.dart';
import '../services/app_services.dart';
import '../widgets/format.dart';
import '../widgets/module_card.dart';
import '../widgets/state_views.dart';

/// Control screen: one card per student module with its actuators.
/// Writes commands to Firebase; the ESP32 reacts within a few seconds.
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  late final Stream<HomeState> _state = widget.services.home.state;
  final _pending = PendingCommands();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _send(Map<String, bool> commands) async {
    setState(() => _pending.add(commands));
    try {
      await widget.services.home.sendCommands(commands);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(commands.keys));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Couldn't send the command: $e")));
    }
  }

  /// A switch that shows the requested value until the ESP32 confirms it.
  Widget _switch(String key, String title, bool actual,
      {String? help, ValueChanged<bool>? onChanged, bool enabled = true, IconData? icon}) {
    final waiting = _pending.isPending(key, actual);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: waiting
          ? const Text('Sending to ESP32…')
          : (help == null ? null : Text(help)),
      value: _pending.shown(key, actual),
      onChanged: enabled ? (onChanged ?? (v) => _send({key: v})) : null,
    );
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
        final live = home.liveness(s);
        final offline = live == Liveness.offline || live == Liveness.notResponding;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (offline)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'The ESP32 is offline. Commands are saved and will apply when it reconnects.',
                ),
              ),
            ModuleCard(
              module: ModuleInfo.garage,
              liveness: live,
              child: Column(children: [
                _switch('garageOpen', 'Open garage', s.garage.open,
                    icon: Icons.garage,
                    help: 'Distance ${cm(s.garage.distanceCm)}',
                    onChanged: (v) => _send({'garageOpen': v, 'autoMode': false})),
                _switch('autoMode', 'Auto mode (ultrasonic)', s.garage.autoMode,
                    icon: Icons.sensors,
                    help: 'Opens when a car is close; set the distance in Automation'),
              ]),
            ),
            ModuleCard(
              module: ModuleInfo.clothesLine,
              liveness: live,
              child: _switch(
                'windowOpen',
                'Open clothes line',
                s.clothesLine.open,
                icon: s.clothesLine.raining ? Icons.water_drop : Icons.dry_cleaning,
                help: s.clothesLine.raining
                    ? "Raining: it stays closed until it's dry"
                    : 'Closes by itself when it rains',
                enabled: !(s.clothesLine.raining && !s.clothesLine.open),
              ),
            ),
            ModuleCard(
              module: ModuleInfo.fireAlarm,
              liveness: live,
              highlight: s.fire.detected ? Colors.red.withValues(alpha: 0.12) : null,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.local_fire_department,
                    color: s.fire.detected ? Colors.red : null),
                title: Text(s.fire.detected ? 'Fire detected!' : 'No flame'),
                subtitle: Text('Buzzer ${s.fire.buzzerOn ? 'sounding' : 'off'}'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: s.fire.buzzerOn ? () => _send({'silenceBuzzer': true}) : null,
                  child: const Text('Silence'),
                ),
              ),
            ),
            ModuleCard(
              module: ModuleInfo.fan,
              liveness: live,
              child: _switch('fanOn', 'Fan on', s.fanOn, icon: Icons.mode_fan_off_outlined),
            ),
            ModuleCard(
              module: ModuleInfo.lights,
              liveness: live,
              child: Column(children: [
                for (var i = 1; i <= 3; i++)
                  _switch('led$i', 'Light $i', s.lights[i - 1], icon: Icons.lightbulb_outline),
              ]),
            ),
          ],
        );
      },
    );
  }
}
