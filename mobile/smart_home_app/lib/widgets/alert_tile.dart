import 'package:flutter/material.dart';

import '../models/home_alert.dart';

/// A coloured row for one alert (critical = red, warning = orange, info = blue).
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, this.action});
  final HomeAlert alert;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (alert.level) {
      AlertLevel.critical => (Colors.red, Icons.local_fire_department),
      AlertLevel.warning => (Colors.orange, Icons.warning_amber_rounded),
      AlertLevel.info => (Colors.blue, Icons.info_outline),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(alert.message),
        trailing: action,
      ),
    );
  }
}
