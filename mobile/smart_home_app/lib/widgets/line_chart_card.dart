import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A titled line chart of (time, value) points.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.color,
  });

  final String title;
  final String unit;
  final List<(DateTime, double)> points;
  final Color color;

  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: const Text('Not enough readings yet for a chart.'),
        ),
      );
    }
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final spots = [
      for (final p in points)
        FlSpot((p.$1.millisecondsSinceEpoch - t0) / 60000, p.$2),
    ];
    final latest = points.last.$2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('$title · now ${latest.toStringAsFixed(1)} $unit',
                  style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0),
                            style: theme.textTheme.labelSmall),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (spots.last.x / 3).clamp(1, double.infinity),
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hhmm(DateTime.fromMillisecondsSinceEpoch(
                                (t0 + v * 60000).toInt())),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
