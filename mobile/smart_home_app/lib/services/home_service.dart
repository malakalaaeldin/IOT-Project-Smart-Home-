import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/automation_settings.dart';
import '../models/history_reading.dart';
import '../models/home_state.dart';
import '../models/schedule.dart';
import 'live_value.dart';

/// All Realtime Database access for the house: live state, commands,
/// automation settings, schedules and history. Screens never touch Firebase.
///
/// Data layout (/smartHome):
///   commands/{garageOpen, windowOpen, fanOn, led1..4, autoMode, silenceBuzzer}  app -> ESP32
///   garage, window (clothes line), fan, lights, fire, status                     ESP32 -> app
///   settings/{garageDetectCm, garageCloseDelaySec, clothesLineFollowsRain, historyIntervalSec}
///   schedules/{id} + scheduleIndex/m{utcMinute} = "key=1,key=0"                  app -> ESP32
///   history/{pushId}/{t, distanceCm, raining, fire, rssi, ...}                   ESP32 -> app
class HomeService {
  HomeService({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance {
    _raw = LiveValue(_home.onValue.map((e) => asStringMap(e.snapshot.value)));
    _connected = LiveValue(
      _db.ref('.info/connected').onValue.map((e) => e.snapshot.value == true),
    );
    _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _serverOffsetMs = v.toInt();
    });
  }

  final FirebaseDatabase _db;
  DatabaseReference get _home => _db.ref('smartHome');

  late final LiveValue<Map<String, dynamic>> _raw;
  late final LiveValue<bool> _connected;
  int _serverOffsetMs = 0;

  // ---------------------------------------------------------------- live state

  Stream<HomeState> get state => _raw.stream.map(HomeState.fromMap);
  HomeState? get latest => _raw.hasValue ? HomeState.fromMap(_raw.value!) : null;

  /// Raw tree, for the chat assistant.
  Map<String, dynamic> get latestRaw => _raw.value ?? const {};

  /// False when the phone has no connection to Firebase (no internet).
  Stream<bool> get connected => _connected.stream;

  DateTime get serverNow =>
      DateTime.now().add(Duration(milliseconds: _serverOffsetMs));

  // Fallback for old firmware that wrote uptime (not a timestamp) as lastSeen:
  // online if the value keeps changing.
  Object? _legacySeen;
  DateTime? _legacyChangedAt;
  final DateTime _startedAt = DateTime.now();
  static const _staleAfter = Duration(seconds: 20);

  /// Online if the ESP32's heartbeat (every 5 s) is less than 20 s old.
  Liveness liveness(HomeState s) {
    final seen = s.status.lastSeenMs;
    if (seen != null && seen > 1000000000000) {
      final age = serverNow.difference(DateTime.fromMillisecondsSinceEpoch(seen));
      if (age < _staleAfter) return Liveness.online;
      return s.status.reportedOnline ? Liveness.notResponding : Liveness.offline;
    }
    if (seen != _legacySeen) {
      if (_legacySeen != null) _legacyChangedAt = DateTime.now();
      _legacySeen = seen;
    }
    if (!s.status.reportedOnline) return Liveness.offline;
    final changed = _legacyChangedAt;
    if (changed != null && DateTime.now().difference(changed) < _staleAfter) {
      return Liveness.online;
    }
    return DateTime.now().difference(_startedAt) < _staleAfter
        ? Liveness.checking
        : Liveness.notResponding;
  }

  /// When the board was last heard from (null if unknown).
  DateTime? lastSeen(HomeState s) {
    final seen = s.status.lastSeenMs;
    if (seen != null && seen > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(seen);
    }
    return _legacyChangedAt;
  }

  // ------------------------------------------------------------------ commands

  /// Writes commands in one atomic update. Manual garage control turns
  /// auto mode off (the firmware expects both together).
  Future<void> sendCommands(Map<String, bool> commands, {Map<String, Object?>? voiceLog}) {
    final updates = <String, Object?>{
      for (final e in commands.entries) 'commands/${e.key}': e.value,
    };
    if (commands.containsKey('garageOpen') && !commands.containsKey('autoMode')) {
      updates['commands/autoMode'] = false;
    }
    if (voiceLog != null) {
      updates['voice/last'] = {...voiceLog, 'at': ServerValue.timestamp};
    }
    return _home.update(updates);
  }

  // ------------------------------------------------------- automation settings

  late final LiveValue<AutomationSettings> _settings = LiveValue(
    _home.child('settings').onValue.map(
          (e) => AutomationSettings.fromMap(asStringMap(e.snapshot.value)),
        ),
  );

  Stream<AutomationSettings> get settings => _settings.stream;

  /// Admin only (enforced by the database rules).
  Future<void> saveSettings(AutomationSettings s) =>
      _home.child('settings').set(s.toMap());

  // ----------------------------------------------------------------- schedules

  late final LiveValue<List<Schedule>> _schedules = LiveValue(
    _home.child('schedules').onValue.map((e) {
      final map = asStringMap(e.snapshot.value);
      final list = <Schedule>[];
      map.forEach((id, v) {
        final s = Schedule.fromMap(id, asStringMap(v));
        if (s != null) list.add(s);
      });
      list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      return list;
    }),
  );

  Stream<List<Schedule>> get schedules => _schedules.stream;

  Future<void> addSchedule(ScheduleAction action, int hour, int minute) async {
    final ref = _home.child('schedules').push();
    await ref.set(Schedule(
      id: ref.key!,
      action: action,
      hour: hour,
      minute: minute,
      utcMinute: Schedule.toUtcMinute(hour, minute),
      enabled: true,
    ).toMap());
    await _rebuildScheduleIndex();
  }

  Future<void> setScheduleEnabled(String id, bool enabled) async {
    await _home.child('schedules/$id/enabled').set(enabled);
    await _rebuildScheduleIndex();
  }

  Future<void> deleteSchedule(String id) async {
    await _home.child('schedules/$id').remove();
    await _rebuildScheduleIndex();
  }

  /// The ESP32 reads one small entry per minute: `scheduleIndex/m{utcMinute}`.
  Future<void> _rebuildScheduleIndex() async {
    final snap = await _home.child('schedules').get();
    final index = <String, List<String>>{};
    asStringMap(snap.value).forEach((id, v) {
      final s = Schedule.fromMap(id, asStringMap(v));
      if (s == null || !s.enabled) return;
      index
          .putIfAbsent('m${s.utcMinute}', () => [])
          .add('${s.action.commandKey}=${s.action.value ? 1 : 0}');
    });
    await _home.child('scheduleIndex').set(
          index.map((k, v) => MapEntry(k, v.join(','))),
        );
  }

  // ------------------------------------------------------------------- history

  late final LiveValue<List<HistoryReading>> _history = LiveValue(
    _home.child('history').orderByChild('t').limitToLast(120).onValue.map((e) {
      final list = <HistoryReading>[];
      asStringMap(e.snapshot.value).forEach((_, v) {
        final r = HistoryReading.fromMap(asStringMap(v));
        if (r != null) list.add(r);
      });
      list.sort((a, b) => a.time.compareTo(b.time));
      return list;
    }),
  );

  /// The last 120 readings, oldest first.
  Stream<List<HistoryReading>> get history => _history.stream;

  void dispose() {
    _raw.dispose();
    _connected.dispose();
    _settings.dispose();
    _schedules.dispose();
    _history.dispose();
  }
}
