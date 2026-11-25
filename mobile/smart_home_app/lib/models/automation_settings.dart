/// Automation thresholds stored in `/smartHome/settings`.
///
/// The ESP32 reads these every 10 s and applies them, so changing them here
/// changes how the hardware behaves (project requirement).
class AutomationSettings {
  const AutomationSettings({
    this.garageDetectCm = 15,
    this.garageCloseDelaySec = 3,
    this.clothesLineFollowsRain = true,
    this.historyIntervalSec = 30,
  });

  /// Garage auto mode opens when something is this close (cm).
  final int garageDetectCm;

  /// Garage closes this many seconds after the car leaves.
  final int garageCloseDelaySec;

  /// true: wet closes the clothes line and dry reopens it.
  /// false: rain only closes it; reopen from the app.
  final bool clothesLineFollowsRain;

  /// How often the ESP32 stores a history reading.
  final int historyIntervalSec;

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

  factory AutomationSettings.fromMap(Map<String, dynamic> m) {
    const d = AutomationSettings();
    return AutomationSettings(
      garageDetectCm: _int(m['garageDetectCm'], d.garageDetectCm),
      garageCloseDelaySec: _int(m['garageCloseDelaySec'], d.garageCloseDelaySec),
      clothesLineFollowsRain: m['clothesLineFollowsRain'] is bool
          ? m['clothesLineFollowsRain'] as bool
          : d.clothesLineFollowsRain,
      historyIntervalSec: _int(m['historyIntervalSec'], d.historyIntervalSec),
    );
  }

  Map<String, Object> toMap() => {
        'garageDetectCm': garageDetectCm,
        'garageCloseDelaySec': garageCloseDelaySec,
        'clothesLineFollowsRain': clothesLineFollowsRain,
        'historyIntervalSec': historyIntervalSec,
      };

  AutomationSettings copyWith({
    int? garageDetectCm,
    int? garageCloseDelaySec,
    bool? clothesLineFollowsRain,
    int? historyIntervalSec,
  }) =>
      AutomationSettings(
        garageDetectCm: garageDetectCm ?? this.garageDetectCm,
        garageCloseDelaySec: garageCloseDelaySec ?? this.garageCloseDelaySec,
        clothesLineFollowsRain: clothesLineFollowsRain ?? this.clothesLineFollowsRain,
        historyIntervalSec: historyIntervalSec ?? this.historyIntervalSec,
      );
}
