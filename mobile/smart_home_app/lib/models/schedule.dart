/// A daily scheduled action, stored in `/smartHome/schedules/{id}`.
///
/// Time is kept as local hour/minute (for display) plus [utcMinute], the minute
/// of the day in UTC that the ESP32 compares with its NTP clock.
class Schedule {
  const Schedule({
    required this.id,
    required this.action,
    required this.hour,
    required this.minute,
    required this.utcMinute,
    required this.enabled,
  });

  final String id;
  final ScheduleAction action;
  final int hour;
  final int minute;
  final int utcMinute;
  final bool enabled;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Converts a local time to the UTC minute of the day.
  static int toUtcMinute(int hour, int minute, {Duration? offset}) {
    final off = offset ?? DateTime.now().timeZoneOffset;
    return ((hour * 60 + minute - off.inMinutes) % 1440 + 1440) % 1440;
  }

  static Schedule? fromMap(String id, Map<String, dynamic> m) {
    final action = ScheduleAction.byId(m['action']?.toString());
    if (action == null) return null;
    return Schedule(
      id: id,
      action: action,
      hour: (m['hour'] as num?)?.toInt() ?? 0,
      minute: (m['minute'] as num?)?.toInt() ?? 0,
      utcMinute: (m['utcMinute'] as num?)?.toInt() ?? 0,
      enabled: m['enabled'] != false,
    );
  }

  Map<String, Object> toMap() => {
        'action': action.id,
        'hour': hour,
        'minute': minute,
        'utcMinute': utcMinute,
        'enabled': enabled,
      };
}

/// Things a schedule can do: one command key + value.
class ScheduleAction {
  const ScheduleAction(this.id, this.label, this.commandKey, this.value);
  final String id;
  final String label;
  final String commandKey;
  final bool value;

  static const all = <ScheduleAction>[
    ScheduleAction('garage_open', 'Open garage', 'garageOpen', true),
    ScheduleAction('garage_close', 'Close garage', 'garageOpen', false),
    ScheduleAction('clothes_open', 'Open clothes line', 'windowOpen', true),
    ScheduleAction('clothes_close', 'Close clothes line', 'windowOpen', false),
    ScheduleAction('fan_on', 'Fan on', 'fanOn', true),
    ScheduleAction('fan_off', 'Fan off', 'fanOn', false),
    ScheduleAction('light1_on', 'Light 1 on', 'led1', true),
    ScheduleAction('light1_off', 'Light 1 off', 'led1', false),
    ScheduleAction('light2_on', 'Light 2 on', 'led2', true),
    ScheduleAction('light2_off', 'Light 2 off', 'led2', false),
    ScheduleAction('light3_on', 'Light 3 on', 'led3', true),
    ScheduleAction('light3_off', 'Light 3 off', 'led3', false),
    ScheduleAction('auto_on', 'Garage auto mode on', 'autoMode', true),
  ];

  static ScheduleAction? byId(String? id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
