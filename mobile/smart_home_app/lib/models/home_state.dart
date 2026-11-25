/// Typed view of the live `/smartHome` tree written by the ESP32.
library;

/// Converts any Firebase map (with Object? keys) into a String-keyed map.
Map<String, dynamic> asStringMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map(
    (k, v) => MapEntry(k.toString(), v is Map ? asStringMap(v) : v),
  );
}

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;
int? _toInt(Object? v) => v is num ? v.toInt() : null;

/// Online/offline state of the ESP32, derived from its heartbeat.
enum Liveness { online, checking, notResponding, offline }

class DeviceStatus {
  const DeviceStatus({
    required this.reportedOnline,
    this.lastSeenMs,
    this.wifiRssi,
    this.uptimeSec,
  });

  /// What the board last wrote; stays true if it loses power, so it is not
  /// enough on its own (see HomeService.liveness).
  final bool reportedOnline;

  /// Server timestamp (ms) of the last heartbeat. Older firmware wrote the
  /// board's uptime in seconds here instead.
  final int? lastSeenMs;
  final int? wifiRssi;
  final int? uptimeSec;

  factory DeviceStatus.fromMap(Map<String, dynamic> m) => DeviceStatus(
        reportedOnline: m['online'] == true,
        lastSeenMs: _toInt(m['lastSeen']),
        wifiRssi: _toInt(m['wifiRssi']),
        uptimeSec: _toInt(m['uptimeSec']),
      );
}

class GarageState {
  const GarageState({required this.open, required this.autoMode, this.distanceCm});
  final bool open;
  final bool autoMode;
  final double? distanceCm;

  factory GarageState.fromMap(Map<String, dynamic> m) => GarageState(
        open: m['open'] == true,
        autoMode: m['autoMode'] != false,
        distanceCm: _toDouble(m['distanceCm']),
      );
}

/// Rain-sensor servo (stored as `window` in Firebase, shown as "Clothes line").
class ClothesLineState {
  const ClothesLineState({required this.open, required this.raining});
  final bool open;
  final bool raining;

  factory ClothesLineState.fromMap(Map<String, dynamic> m) =>
      ClothesLineState(open: m['open'] == true, raining: m['raining'] == true);
}

class FireState {
  const FireState({required this.detected, required this.buzzerOn});
  final bool detected;
  final bool buzzerOn;

  factory FireState.fromMap(Map<String, dynamic> m) =>
      FireState(detected: m['detected'] == true, buzzerOn: m['buzzerOn'] == true);
}

class HomeState {
  const HomeState({
    required this.raw,
    required this.status,
    required this.garage,
    required this.clothesLine,
    required this.fire,
    required this.fanOn,
    required this.lights,
  });

  /// The untyped tree (used by the chat assistant).
  final Map<String, dynamic> raw;
  final DeviceStatus status;
  final GarageState garage;
  final ClothesLineState clothesLine;
  final FireState fire;
  final bool fanOn;

  /// General control lights 1..3 (led1..led3) in order.
  final List<bool> lights;

  /// True when the database has no data yet (ESP32 never connected).
  bool get isEmpty => raw.isEmpty;

  int get lightsOn => lights.where((l) => l).length;

  factory HomeState.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> s(String k) => asStringMap(m[k]);
    final lights = s('lights');
    return HomeState(
      raw: m,
      status: DeviceStatus.fromMap(s('status')),
      garage: GarageState.fromMap(s('garage')),
      clothesLine: ClothesLineState.fromMap(s('window')),
      fire: FireState.fromMap(s('fire')),
      fanOn: s('fan')['on'] == true,
      lights: [for (var i = 1; i <= 3; i++) lights['led$i'] == true],
    );
  }
}
