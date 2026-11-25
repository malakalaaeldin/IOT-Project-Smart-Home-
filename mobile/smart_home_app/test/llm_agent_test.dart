import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/services/assistant/llm_agent.dart';

void main() {
  test('parses JSON reply and keeps only allowed keys', () {
    final r = parseLlmReply(
      'Sure! {"actions":[{"key":"windowOpen","value":true},'
      '{"key":"led3","value":true},{"key":"selfDestruct","value":true},'
      '{"key":"led1","value":"yes"},{"key":"led4","value":true}],"reply":"Welcome home!"}',
    );
    expect(r, isNotNull);
    expect(r!.actions, {'windowOpen': true, 'led3': true});
    expect(r.reply, 'Welcome home!');
  });

  test('plain prose is spoken but never acted on', () {
    final r = parseLlmReply('Closing the garage and turning off lights.');
    expect(r!.actions, isEmpty);
    expect(r.reply, 'Closing the garage and turning off lights.');
    expect(parseLlmReply('   '), isNull);
  });

  test('empty reply falls back to description', () {
    final r = parseLlmReply('{"actions":[{"key":"garageOpen","value":false}],"reply":""}');
    expect(r!.reply, 'Closing the garage.');
  });
}
