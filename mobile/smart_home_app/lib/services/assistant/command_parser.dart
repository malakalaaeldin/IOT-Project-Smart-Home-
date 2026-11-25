/// Offline, rule-based intent parser for the Calm Hills chat assistant.
///
/// Handles command-style messages instantly with no network:
///   "open the garage door", "close the clothes line", "turn on the fan",
///   "turn on light 1 and light 3", "all lights off",
///   "silence the alarm", "is the garage open?", "status".
///
/// Anything it cannot understand is returned with [VoiceResult.understood]
/// false so the caller can hand it to the LLM agent.
///
/// Keep this file in sync with web/voice/parser.js.
library;

/// Command keys under /smartHome/commands that the agent may write.
const commandKeys = <String>{
  'garageOpen',
  'windowOpen',
  'fanOn',
  'led1',
  'led2',
  'led3',
  'autoMode',
  'silenceBuzzer',
};

/// The three "general control lights".
const lightNames = <String, String>{
  'led1': 'light 1',
  'led2': 'light 2',
  'led3': 'light 3',
};
const _allLights = ['led1', 'led2', 'led3'];

/// "light 2" or "lights 1 and 3".
String _lightList(List<String> keys) {
  final nums = keys.map((k) => k.substring(3)).toList();
  if (nums.length == 1) return 'light ${nums.first}';
  return 'lights ${nums.sublist(0, nums.length - 1).join(', ')} and ${nums.last}';
}

class VoiceResult {
  const VoiceResult({
    required this.actions,
    required this.reply,
    required this.understood,
    this.confident = true,
  });

  /// Command key -> value, in the order they were spoken.
  final Map<String, bool> actions;
  final String reply;
  final bool understood;

  /// False when part of the sentence was not understood. The agent then
  /// prefers the LLM and keeps this result only as a fallback.
  final bool confident;

  static const VoiceResult empty =
      VoiceResult(actions: {}, reply: '', understood: false);
}

/// Wake phrases. In hands-free mode an utterance must start with one.
final _wake = RegExp(
  r'^(?:(?:hey|hi|okay|ok|hello)\s+)?(?:home|house|calm hills)\b[\s,]*',
);

/// True when [text] begins with a wake phrase such as "hey home".
bool hasWakeWord(String text) => _wake.hasMatch(normalize(text));

/// Removes the wake phrase, if present.
String stripWakeWord(String text) => normalize(text).replaceFirst(_wake, '');

String normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9'\s,]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

enum _Verb { on, off }

_Verb? _verbOf(String c) {
  // Order matters: check "off"-style phrases before bare "on".
  if (RegExp(r'\b(close|shut|lock|lower|off|kill|disable|deactivate|stop|silence|mute|quiet|hush)\b')
      .hasMatch(c)) {
    return _Verb.off;
  }
  if (RegExp(r'\b(open|unlock|raise|lift|on|light up|enable|activate|start|brighten|bright|brighter)\b')
      .hasMatch(c)) {
    return _Verb.on;
  }
  return null;
}

List<String> _devicesOf(String c) {
  final out = <String>[];
  void add(String k) {
    if (!out.contains(k)) out.add(k);
  }

  if (RegExp(r'\bgarage\b').hasMatch(c)) add('garageOpen');
  if (RegExp(r'\b(clothes ?lines?|washing lines?|laundry|clothes|windows?|roof|rain cover)\b')
      .hasMatch(c)) {
    add('windowOpen');
  }
  if (RegExp(r'\b(fans?|ventilation|ventilator|air)\b').hasMatch(c)) add('fanOn');

  final allLights = RegExp(
    r'\b(all|every|everything|all the|whole house)\b.*\b(lights?|leds?|lamps?)\b|\b(lights?|leds?|lamps?)\b.*\b(everywhere|all)\b',
  ).hasMatch(c);
  if (allLights) {
    for (final k in _allLights) {
      add(k);
    }
  } else {
    // "light 1", "light one", "first light", "led 1"; a bare number in a
    // list ("lights 1 and 3" splits into "lights 1" + "3") also counts.
    const words = {'1': 'one|first', '2': 'two|second', '3': 'three|third'};
    words.forEach((n, w) {
      final named = RegExp('\\b((lights?|lamps?|leds?) ?($n|$w)|($w) (light|lamp))\\b');
      final bare = RegExp('^(the )?($n|$w)( lights?)?\$');
      if (named.hasMatch(c) || bare.hasMatch(c.trim())) add('led$n');
    });
  }

  if (RegExp(r'\b(auto mode|automatic|auto|ultrasonic|sensor mode)\b')
      .hasMatch(c)) {
    add('autoMode');
  }
  if (RegExp(r'\b(silence|mute|quiet|buzzer|alarm|siren)\b').hasMatch(c)) {
    add('silenceBuzzer');
  }
  return out;
}

bool _isQuestion(String c) => RegExp(
      r"^(is|are|was|what|what's|whats|how|which|tell me|give me|any|do i|did i|status|report)\b|\bstatus\b|\?$",
    ).hasMatch(c);

/// Parses [utterance] against the live [state] (the /smartHome snapshot).
VoiceResult parseCommand(String utterance, Map<String, dynamic> state) {
  final text = stripWakeWord(utterance);
  if (text.isEmpty) {
    return const VoiceResult(
      actions: {},
      reply: 'Yes? Tell me what to do.',
      understood: true,
    );
  }

  if (_isQuestion(text) && _verbOfQuestion(text)) {
    final answer = answerQuestion(text, state);
    if (answer != null) {
      return VoiceResult(actions: const {}, reply: answer, understood: true);
    }
  }

  final clauses = text
      .split(RegExp(r'\s*(?:,|\band then\b|\bthen\b|\band\b|\balso\b|\bplus\b)\s*'))
      .where((s) => s.isNotEmpty)
      .toList();

  final actions = <String, bool>{};
  var confident = true;
  _Verb? lastVerb;
  for (final clause in clauses) {
    var devices = _devicesOf(clause);
    final verb = _verbOf(clause) ?? lastVerb;
    // "lights on" with no room: all lights.
    if (devices.isEmpty &&
        RegExp(r'\b(lights?|lamps?|leds?)\b').hasMatch(clause)) {
      devices = [..._allLights];
    }
    if (devices.isEmpty || verb == null) {
      // A clause we could not act on. Pleasantries are fine; anything else
      // means we only half understood, so the LLM should take the request.
      if (!_filler.hasMatch(clause)) confident = false;
      continue;
    }
    lastVerb = verb;
    for (final d in devices) {
      if (d == 'silenceBuzzer') {
        actions[d] = true; // "silence", "stop the alarm", "turn off buzzer"
      } else {
        actions[d] = verb == _Verb.on;
      }
    }
  }

  if (actions.isEmpty) {
    return VoiceResult(
      actions: const {},
      reply: "Sorry, I didn't understand \"$text\".",
      understood: false,
    );
  }
  return VoiceResult(
    actions: actions,
    reply: describeActions(actions),
    understood: true,
    confident: confident,
  );
}

final _filler = RegExp(
  r"^(please|thanks|thank you|now|quickly|for me|hi|hello|hey|okay|ok|"
  r"(i'm|im|i am|we're|were|we are) (home|back|here)|i'm back|welcome)$",
);

bool _verbOfQuestion(String c) =>
    // "is the garage open" is a question, "open the garage" is not.
    !RegExp(r'^(open|close|shut|turn|switch|lock|unlock|silence|mute|enable|disable|let)\b')
        .hasMatch(c);

/// Builds a spoken confirmation such as
/// "Opening the garage and turning on light 1."
String describeActions(Map<String, bool> actions) {
  final parts = <String>[];
  final lightsOn = <String>[];
  final lightsOff = <String>[];
  actions.forEach((k, v) {
    switch (k) {
      case 'garageOpen':
        parts.add(v ? 'opening the garage' : 'closing the garage');
      case 'windowOpen':
        parts.add(v ? 'opening the clothes line' : 'closing the clothes line');
      case 'fanOn':
        parts.add(v ? 'turning the fan on' : 'turning the fan off');
      case 'autoMode':
        parts.add(v ? 'turning auto mode on' : 'turning auto mode off');
      case 'silenceBuzzer':
        parts.add('silencing the alarm');
      default:
        if (lightNames.containsKey(k)) (v ? lightsOn : lightsOff).add(k);
    }
  });
  String lights(List<String> ks, String verb) {
    if (ks.length == _allLights.length) return 'turning $verb all the lights';
    return 'turning $verb ${_lightList(ks)}';
  }

  if (lightsOn.isNotEmpty) parts.add(lights(lightsOn, 'on'));
  if (lightsOff.isNotEmpty) parts.add(lights(lightsOff, 'off'));
  if (parts.isEmpty) return 'Done.';
  final sentence = parts.length == 1
      ? parts.first
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  return '${sentence[0].toUpperCase()}${sentence.substring(1)}.';
}

Map<String, dynamic> _section(Map<String, dynamic> s, String k) {
  final v = s[k];
  if (v is Map) return v.map((a, b) => MapEntry(a.toString(), b));
  return {};
}

/// Answers status questions from the live state; null if not a known topic.
String? answerQuestion(String text, Map<String, dynamic> state) {
  final garage = _section(state, 'garage');
  final window = _section(state, 'window');
  final fan = _section(state, 'fan');
  final lights = _section(state, 'lights');
  final fire = _section(state, 'fire');
  final status = _section(state, 'status');

  String openWord(dynamic v) => v == true ? 'open' : 'closed';
  String lightsSummary() {
    final on = _allLights.where((k) => lights[k] == true).toList();
    if (on.isEmpty) return 'All lights are off.';
    if (on.length == _allLights.length) return 'All lights are on.';
    final list = _lightList(on);
    return '${list[0].toUpperCase()}${list.substring(1)} ${on.length > 1 ? 'are' : 'is'} on.';
  }

  if (RegExp(r'\b(fire|flame|smoke|alarm|buzzer)\b').hasMatch(text)) {
    return fire['detected'] == true
        ? 'Warning: fire is detected! The buzzer is ${fire['buzzerOn'] == true ? 'sounding' : 'silenced'}.'
        : 'No fire detected. Everything is safe.';
  }
  if (RegExp(r'\b(distance|far|car|parked|ultrasonic)\b').hasMatch(text)) {
    final d = garage['distanceCm'];
    return d is num
        ? 'The garage sensor reads ${d.toStringAsFixed(0)} centimetres.'
        : 'I have no distance reading yet.';
  }
  if (RegExp(r'\bgarage\b').hasMatch(text)) {
    return 'The garage is ${openWord(garage['open'])}.';
  }
  if (RegExp(r'\b(rain|raining|wet|weather)\b').hasMatch(text)) {
    return window['raining'] == true
        ? "It's raining, so the clothes line is closed."
        : 'No rain right now. The clothes line is ${openWord(window['open'])}.';
  }
  if (RegExp(r'\b(clothes ?lines?|washing lines?|laundry|clothes|windows?|roof)\b')
      .hasMatch(text)) {
    return 'The clothes line is ${openWord(window['open'])}.';
  }
  if (RegExp(r'\b(fans?|ventilation)\b').hasMatch(text)) {
    return 'The fan is ${fan['on'] == true ? 'on' : 'off'}.';
  }
  if (RegExp(r'\b(lights?|lamps?|leds?)\b').hasMatch(text)) {
    return lightsSummary();
  }
  if (RegExp(r'\b(online|connected|esp|device|wifi)\b').hasMatch(text)) {
    return status['online'] == true
        ? 'The ESP32 is online.'
        : 'The ESP32 is offline.';
  }
  if (RegExp(r'\b(status|everything|house|home|report|going on)\b')
      .hasMatch(text)) {
    return 'Garage ${openWord(garage['open'])}, clothes line ${openWord(window['open'])}'
        '${window['raining'] == true ? ' (raining)' : ''}, fan ${fan['on'] == true ? 'on' : 'off'}. '
        '${lightsSummary()} '
        '${fire['detected'] == true ? 'Fire detected!' : 'No fire.'}';
  }
  return null;
}
