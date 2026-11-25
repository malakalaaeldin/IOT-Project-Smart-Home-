import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/services/assistant/command_parser.dart';

void main() {
  final state = <String, dynamic>{
    'garage': {'open': false, 'distanceCm': 42.4, 'autoMode': true},
    'window': {'open': true, 'raining': false},
    'fan': {'on': false},
    'lights': {'led1': true, 'led2': false, 'led3': true},
    'fire': {'detected': false, 'buzzerOn': false},
    'status': {'online': true},
  };

  Map<String, bool> act(String s) => parseCommand(s, state).actions;

  group('device commands', () {
    test('garage', () {
      expect(act('open the garage door'), {'garageOpen': true});
      expect(act('Close the garage.'), {'garageOpen': false});
      expect(act('hey home, open garage'), {'garageOpen': true});
    });

    test('clothes line and fan', () {
      expect(act('close the clothes line'), {'windowOpen': false});
      expect(act('open the clothesline'), {'windowOpen': true});
      expect(act('open the washing line'), {'windowOpen': true});
      expect(act('open the window'), {'windowOpen': true});
      expect(act('close the roof'), {'windowOpen': false});
      expect(act('turn on the fan'), {'fanOn': true});
      expect(act('open the fan'), {'fanOn': true});
      expect(act('switch the fan off'), {'fanOn': false});
      expect(act("it's raining outside, close the window"), {'windowOpen': false});
    });

    test('general control lights 1-3', () {
      expect(act('turn on light 1'), {'led1': true});
      expect(act('switch off light two'), {'led2': false});
      expect(act('turn the third light off'), {'led3': false});
      expect(act('light 3 on'), {'led3': true});
      expect(act('turn on led 2'), {'led2': true});
      expect(act('turn on the porch light'), {'led1': true, 'led2': true, 'led3': true});
    });

    test('all lights', () {
      final all = {'led1': false, 'led2': false, 'led3': false};
      expect(act('turn off all the lights'), all);
      expect(act('lights off'), all);
    });

    test('compound commands carry the verb', () {
      expect(act('turn on lights 1 and 3'), {'led1': true, 'led3': true});
      expect(act('turn on light 1 and light 2'), {'led1': true, 'led2': true});
      expect(act('open the garage and the window'),
          {'garageOpen': true, 'windowOpen': true});
      expect(act('close the garage, then turn off light 2'),
          {'garageOpen': false, 'led2': false});
    });

    test('alarm and auto mode', () {
      expect(act('silence the alarm'), {'silenceBuzzer': true});
      expect(act('stop the buzzer'), {'silenceBuzzer': true});
      expect(act('turn off auto mode'), {'autoMode': false});
      expect(act('enable automatic mode'), {'autoMode': true});
    });

    test('confirmation text', () {
      expect(parseCommand('open the garage and turn on light 1', state).reply,
          'Opening the garage and turning on light 1.');
      expect(parseCommand('turn off lights 1 and 2', state).reply,
          'Turning off lights 1 and 2.');
      expect(parseCommand('turn off all the lights', state).reply,
          'Turning off all the lights.');
    });
  });

  group('questions', () {
    String reply(String s) => parseCommand(s, state).reply;
    test('answers from live state', () {
      expect(reply('is the garage open?'), 'The garage is closed.');
      expect(reply('is the clothes line open'), 'The clothes line is open.');
      expect(reply('is it raining?'), 'No rain right now. The clothes line is open.');
      expect(reply('is the fan on'), 'The fan is off.');
      expect(reply('which lights are on'), 'Lights 1 and 3 are on.');
      expect(reply('is there a fire'), 'No fire detected. Everything is safe.');
      expect(reply('how far is the car'), 'The garage sensor reads 42 centimetres.');
      expect(parseCommand('status', state).actions, isEmpty);
    });
  });

  group('fallback and wake word', () {
    test('unknown speech is not understood', () {
      final r = parseCommand('play some jazz music', state);
      expect(r.understood, isFalse);
      expect(r.actions, isEmpty);
    });

    test('half-understood sentences are not confident', () {
      final r = parseCommand("it's getting dark outside, turn on light 2", state);
      expect(r.actions, {'led2': true});
      expect(r.confident, isFalse);
      expect(parseCommand("I'm home, turn on light 1", state).confident, isTrue);
      expect(parseCommand('open the garage please', state).confident, isTrue);
    });

    test('wake word detection', () {
      expect(hasWakeWord('Hey Home open the garage'), isTrue);
      expect(hasWakeWord('home, lights off'), isTrue);
      expect(hasWakeWord('open the garage'), isFalse);
      expect(stripWakeWord('OK home, open the garage'), 'open the garage');
    });
  });
}
