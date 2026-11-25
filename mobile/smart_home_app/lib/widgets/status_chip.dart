import 'package:flutter/material.dart';

import '../models/home_state.dart';

/// Online / offline pill for a module (all modules share the ESP32 heartbeat).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.liveness});
  final Liveness liveness;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (liveness) {
      Liveness.online => ('Online', Colors.green, Icons.circle),
      Liveness.checking => ('Checking…', Colors.blueGrey, Icons.more_horiz),
      Liveness.notResponding => ('Not responding', Colors.orange, Icons.circle_outlined),
      Liveness.offline => ('Offline', Colors.red, Icons.circle_outlined),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 12, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}
