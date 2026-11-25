import 'package:flutter/material.dart';

import '../services/assistant/chat_agent.dart';

/// Dashboard card: chat with the smart-home assistant (typed commands).
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.agent});
  final ChatAgent agent;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();

  static const _suggestions = [
    'Open the garage',
    'Turn on light 1',
    'Close the clothes line',
    'Is it raining?',
    'Status',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    widget.agent.send(t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.agent,
      builder: (context, _) {
        final a = widget.agent;
        final recent = a.log.length > 6 ? a.log.sublist(a.log.length - 6) : a.log;
        return Card(
          key: const Key('chatPanel'),
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.chat_bubble_outline, color: scheme.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Home assistant',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            a.llm.enabled
                                ? 'Type a command or ask in your own words'
                                : 'Type a direct command',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(label: Text(s), onPressed: a.busy ? null : () => _send(s)),
                    ],
                  ),
                for (final t in recent) _Bubble(turn: t),
                if (a.busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Working on it…'),
                    ]),
                  ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('chatInput'),
                  controller: _input,
                  enabled: !a.busy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'e.g. "open the garage door"',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      key: const Key('chatSend'),
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
                      onPressed: a.busy ? null : _send,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = turn.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: user ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          turn.text,
          style: TextStyle(color: user ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
  }
}
