import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/models/automation_settings.dart';
import 'package:smart_home_app/models/home_alert.dart';
import 'package:smart_home_app/models/home_state.dart';
import 'package:smart_home_app/models/pending_commands.dart';
import 'package:smart_home_app/models/schedule.dart';

void main() {
  group('HomeState', () {
    test('parses the Firebase tree', () {
      final s = HomeState.fromMap(asStringMap({
        'garage': {'open': true, 'autoMode': false, 'distanceCm': 42},
        'window': {'open': false, 'raining': true},
        'fire': {'detected': true, 'buzzerOn': true},
        'fan': {'on': true},
        'lights': {'led1': true, 'led3': true, 'led4': true},
        'status': {'online': true, 'lastSeen': 1795600000000, 'wifiRssi': -60},
      }));
      expect(s.garage.open, isTrue);
      expect(s.garage.autoMode, isFalse);
      expect(s.garage.distanceCm, 42.0);
      expect(s.clothesLine.raining, isTrue);
      expect(s.fire.detected, isTrue);
      expect(s.fanOn, isTrue);
      expect(s.lights, [true, false, true]); // led4 no longer exists
      expect(s.lightsOn, 2);
      expect(s.status.lastSeenMs, 1795600000000);
      expect(s.isEmpty, isFalse);
    });

    test('empty database', () {
      expect(HomeState.fromMap({}).isEmpty, isTrue);
    });
  });

  test('settings fall back to defaults', () {
    final s = AutomationSettings.fromMap({'garageDetectCm': 20});
    expect(s.garageDetectCm, 20);
    expect(s.garageCloseDelaySec, 3);
    expect(s.clothesLineFollowsRain, isTrue);
    expect(s.toMap()['garageDetectCm'], 20);
  });

  test('schedule local time -> UTC minute', () {
    // Egypt summer time (UTC+3): 07:30 local = 04:30 UTC = minute 270.
    expect(Schedule.toUtcMinute(7, 30, offset: const Duration(hours: 3)), 270);
    // Wraps around midnight: 01:00 at UTC+3 = 22:00 UTC the previous day.
    expect(Schedule.toUtcMinute(1, 0, offset: const Duration(hours: 3)), 22 * 60);
  });

  test('alerts from state', () {
    final s = HomeState.fromMap(asStringMap({
      'fire': {'detected': true, 'buzzerOn': true},
      'window': {'raining': true, 'open': true},
    }));
    final alerts = HomeAlert.from(s, Liveness.offline);
    expect(alerts.map((a) => a.id), ['fire', 'offline', 'rain']);
    expect(alerts.first.level, AlertLevel.critical);
    expect(alerts.last.level, AlertLevel.warning); // raining but still open
  });

  test('pending command shows requested value until confirmed', () {
    final p = PendingCommands();
    p.add({'garageOpen': true});
    expect(p.shown('garageOpen', false), isTrue); // waiting for the ESP32
    expect(p.isPending('garageOpen', false), isTrue);
    expect(p.shown('garageOpen', true), isTrue); // confirmed
    expect(p.isPending('garageOpen', true), isFalse);
  });
}
