import 'package:flutter/material.dart';

import '../models/history_reading.dart';
import '../services/app_services.dart';
import '../widgets/format.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/state_views.dart';

/// History of recent sensor readings (the ESP32 stores one every 30 s):
/// charts for the ultrasonic distance and Wi-Fi signal, plus a list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Stream<List<HistoryReading>> _history = widget.services.home.history;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryReading>>(
      stream: _history,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView(message: 'Loading history…');
        final list = snap.data!;
        if (list.isEmpty) {
          return const MessageView(
            icon: Icons.timeline,
            title: 'No history yet',
            message:
                'The ESP32 saves a reading every 30 seconds once it runs the latest firmware.',
          );
        }
        final distance = [
          for (final r in list)
            if (r.distanceCm != null) (r.time, r.distanceCm!),
        ];
        final rssi = [
          for (final r in list)
            if (r.rssi != null) (r.time, r.rssi!.toDouble()),
        ];
        final rainCount = list.where((r) => r.raining).length;
        final fireCount = list.where((r) => r.fire).length;
        final recent = list.reversed.take(30).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Last ${list.length} readings, from ${hhmm(list.first.time)} to ${hhmm(list.last.time)}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LineChartCard(
              title: 'Garage distance',
              unit: 'cm',
              points: distance,
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            LineChartCard(
              title: 'Wi-Fi signal',
              unit: 'dBm',
              points: rssi,
              color: Colors.indigo,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _stat(context, Icons.water_drop, 'Rain readings', '$rainCount', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, Icons.local_fire_department, 'Fire readings', '$fireCount', Colors.red)),
            ]),
            const SizedBox(height: 16),
            Text('Recent readings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final r in recent)
                    ListTile(
                      dense: true,
                      leading: Text(hhmm(r.time),
                          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                      title: Text('Distance ${cm(r.distanceCm)}'),
                      subtitle: Text(
                          'Garage ${r.garageOpen ? 'open' : 'closed'} · clothes line ${r.clothesLineOpen ? 'open' : 'closed'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r.raining) const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                          if (r.fire)
                            const Icon(Icons.local_fire_department, color: Colors.red, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label, String value, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}
