/// One sensor snapshot from `/smartHome/history/{pushId}` (the ESP32 adds one
/// every `settings/historyIntervalSec` seconds).
class HistoryReading {
  const HistoryReading({
    required this.time,
    this.distanceCm,
    this.rssi,
    required this.raining,
    required this.fire,
    required this.garageOpen,
    required this.clothesLineOpen,
  });

  final DateTime time;
  final double? distanceCm;
  final int? rssi;
  final bool raining;
  final bool fire;
  final bool garageOpen;
  final bool clothesLineOpen;

  static HistoryReading? fromMap(Map<String, dynamic> m) {
    final t = m['t'];
    if (t is! num) return null;
    return HistoryReading(
      time: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      distanceCm: (m['distanceCm'] as num?)?.toDouble(),
      rssi: (m['rssi'] as num?)?.toInt(),
      raining: m['raining'] == true,
      fire: m['fire'] == true,
      garageOpen: m['garageOpen'] == true,
      clothesLineOpen: m['clothesLineOpen'] == true,
    );
  }
}
