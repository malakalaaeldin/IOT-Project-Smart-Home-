import 'home_state.dart';

enum AlertLevel { critical, warning, info }

/// A critical event to show in the app (project requirement: alerts).
class HomeAlert {
  const HomeAlert(this.level, this.title, this.message, {this.id = ''});
  final AlertLevel level;
  final String title;
  final String message;
  final String id;

  /// Builds the current alert list from the live state.
  static List<HomeAlert> from(HomeState s, Liveness live) {
    final alerts = <HomeAlert>[];
    if (s.fire.detected) {
      alerts.add(HomeAlert(
        AlertLevel.critical,
        'Fire detected',
        s.fire.buzzerOn ? 'The alarm is sounding.' : 'The alarm was silenced. Check the house.',
        id: 'fire',
      ));
    }
    if (live == Liveness.notResponding || live == Liveness.offline) {
      alerts.add(const HomeAlert(
        AlertLevel.warning,
        'ESP32 offline',
        'No heartbeat from the board. Commands will apply when it reconnects.',
        id: 'offline',
      ));
    }
    if (s.clothesLine.raining) {
      alerts.add(HomeAlert(
        s.clothesLine.open ? AlertLevel.warning : AlertLevel.info,
        "It's raining",
        s.clothesLine.open
            ? 'The clothes line is still open.'
            : 'The clothes line closed itself.',
        id: 'rain',
      ));
    }
    return alerts;
  }
}
