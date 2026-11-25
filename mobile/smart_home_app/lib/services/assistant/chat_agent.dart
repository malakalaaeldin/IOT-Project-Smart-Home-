import 'package:flutter/foundation.dart';

import '../home_service.dart';
import 'command_parser.dart';
import 'llm_agent.dart';

class ChatTurn {
  ChatTurn(this.text, {required this.fromUser, this.source});
  final String text;
  final bool fromUser;

  /// 'local' (offline parser) or 'ai' (LLM) for assistant replies.
  final String? source;
}

/// Text chat assistant: understands typed commands and questions, acts on
/// the house through HomeService, and replies in the chat.
///
/// Direct commands ("open the garage", "turn on light 2") are handled
/// instantly by the offline parser; free-form requests go to the LLM.
class ChatAgent extends ChangeNotifier {
  ChatAgent({required this.home, LlmAgent? llm}) : llm = llm ?? LlmAgent();

  final HomeService home;
  final LlmAgent llm;
  final List<ChatTurn> log = [];
  final List<Map<String, String>> _history = [];
  bool busy = false;
  bool _disposed = false;

  /// Live house state, used to answer questions ("is the garage open?").
  Map<String, dynamic> get state => home.latestRaw;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Handles one message; ignored while the previous one is still running.
  Future<VoiceResult> send(String text) async {
    final said = text.trim();
    if (said.isEmpty || busy) return VoiceResult.empty;
    busy = true;
    log.add(ChatTurn(said, fromUser: true));
    _notify();
    try {
      final result = await _handle(said);
      log.add(ChatTurn(result.$1.reply, fromUser: false, source: result.$2));
      if (log.length > 40) log.removeRange(0, log.length - 40);
      return result.$1;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<(VoiceResult, String)> _handle(String said) async {
    var result = parseCommand(said, state);
    var source = 'local';
    if ((!result.understood || !result.confident) && llm.enabled) {
      final ai = await llm.ask(stripWakeWord(said), state, history: _history);
      if (ai != null) {
        result = ai;
        source = 'ai';
      } else if (!result.understood) {
        result = const VoiceResult(
          actions: {},
          reply: "Sorry, I couldn't reach the AI. Try a direct command like "
              '"open the garage".',
          understood: false,
        );
      }
      // AI unreachable but the parser understood part of it: keep that.
    } else if (!result.understood) {
      result = VoiceResult(
        actions: const {},
        reply: '${result.reply} Try "open the garage" or "turn on light 1".',
        understood: false,
      );
    }

    try {
      await home.sendCommands(result.actions, voiceLog: {
        'text': said,
        'reply': result.reply,
        'source': source,
        'actions': result.actions,
        'device': 'android',
      });
    } catch (e) {
      result = VoiceResult(
        actions: const {},
        reply: "I couldn't reach the house: $e",
        understood: false,
      );
    }

    _history
      ..add({'role': 'user', 'content': said})
      ..add({'role': 'assistant', 'content': result.reply});
    if (_history.length > 8) _history.removeRange(0, _history.length - 8);
    return (result, source);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
