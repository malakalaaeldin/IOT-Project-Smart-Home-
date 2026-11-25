import 'dart:convert';

import 'package:http/http.dart' as http;

import 'command_parser.dart';

/// NVIDIA NIM (OpenAI-compatible) LLM agent for free-form requests.
///
/// The key comes from a compile-time define so it is never committed:
///   flutter run --dart-define-from-file=secrets.json
/// with secrets.json = {"NVIDIA_API_KEY": "nvapi-..."} (gitignored).
class LlmAgent {
  LlmAgent({http.Client? client}) : _client = client ?? http.Client();

  static const apiKey = String.fromEnvironment('NVIDIA_API_KEY');
  static const model = String.fromEnvironment(
    'NVIDIA_MODEL',
    defaultValue: 'nvidia/nemotron-3.5-lightning-30b-a3b',
  );
  static const _endpoint =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  final http.Client _client;

  bool get enabled => apiKey.isNotEmpty;

  /// Structured output: the model must return exactly this shape.
  static final replySchema = {
    'type': 'object',
    'properties': {
      'actions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string', 'enum': commandKeys.toList()},
            'value': {'type': 'boolean'},
          },
          'required': ['key', 'value'],
        },
      },
      'reply': {'type': 'string'},
    },
    'required': ['actions', 'reply'],
  };

  static String systemPrompt(Map<String, dynamic> state) => '''
You are "Home", the chat assistant of the Calm Hills smart home.
You control devices by writing boolean commands. Allowed command keys:
- garageOpen: true opens the garage door, false closes it
- windowOpen: the CLOTHES LINE cover (the user calls it "clothes line"): true opens it, false closes it (it closes by itself when it rains; do not open it while state.window.raining is true)
- fanOn: true turns the fan on, false turns it off
- led1, led2, led3: the three general control lights, "light 1", "light 2", "light 3" (there are no other lights)
- autoMode: garage opens automatically from the ultrasonic sensor
- silenceBuzzer: true silences the fire alarm buzzer
Current house state (JSON): ${jsonEncode(state)}
Reply with ONLY a JSON object, no markdown:
{"actions":[{"key":"<command key>","value":true|false}],"reply":"<one or two short sentences>"}
Use an empty actions list for questions or chit-chat. Answer questions from the state.
If a request is unsafe or impossible, explain briefly in reply and take no action.''';

  /// Returns null on any failure so the caller can fall back gracefully.
  Future<VoiceResult?> ask(
    String utterance,
    Map<String, dynamic> state, {
    List<Map<String, String>> history = const [],
  }) async {
    if (!enabled) return null;
    try {
      final res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0.2,
              'max_tokens': 300,
              'chat_template_kwargs': {'enable_thinking': false},
              'response_format': {
                'type': 'json_schema',
                'json_schema': {'name': 'home_actions', 'schema': replySchema},
              },
              'messages': [
                {'role': 'system', 'content': systemPrompt(state)},
                ...history,
                {'role': 'user', 'content': utterance},
              ],
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final content =
          (body['choices'] as List).first['message']['content'] as String?;
      return parseLlmReply(content ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// Extracts and validates the JSON object the model returned.
VoiceResult? parseLlmReply(String content) {
  final start = content.indexOf('{');
  final end = content.lastIndexOf('}');
  if (start < 0 || end <= start) {
    // Plain prose: speak it, but never act on it.
    final text = content.trim();
    if (text.isEmpty) return null;
    return VoiceResult(actions: const {}, reply: text, understood: true);
  }
  try {
    final obj = jsonDecode(content.substring(start, end + 1)) as Map;
    final actions = <String, bool>{};
    for (final a in (obj['actions'] as List? ?? const [])) {
      if (a is Map && commandKeys.contains(a['key']) && a['value'] is bool) {
        actions[a['key'] as String] = a['value'] as bool;
      }
    }
    final reply = (obj['reply'] ?? '').toString().trim();
    return VoiceResult(
      actions: actions,
      reply: reply.isEmpty ? describeActions(actions) : reply,
      understood: true,
    );
  } catch (_) {
    return null;
  }
}
