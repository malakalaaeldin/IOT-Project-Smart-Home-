/// Commands sent but not yet confirmed by the ESP32. A switch shows the
/// requested value (instead of snapping back) until the board reports it,
/// or until [timeout] passes.
class PendingCommands {
  PendingCommands({this.timeout = const Duration(seconds: 8)});
  final Duration timeout;
  final Map<String, ({bool value, DateTime at})> _pending = {};

  void add(Map<String, bool> commands) {
    final now = DateTime.now();
    commands.forEach((k, v) => _pending[k] = (value: v, at: now));
  }

  void remove(Iterable<String> keys) => keys.forEach(_pending.remove);

  /// The value to display for [key], given what the board reports ([actual]).
  bool shown(String key, bool actual) {
    final p = _pending[key];
    if (p == null) return actual;
    if (actual == p.value || DateTime.now().difference(p.at) > timeout) {
      _pending.remove(key);
      return actual;
    }
    return p.value;
  }

  /// True while [key] waits for confirmation (call after [shown]).
  bool isPending(String key, bool actual) {
    shown(key, actual);
    return _pending.containsKey(key);
  }
}
