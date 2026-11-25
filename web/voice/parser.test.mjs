// Run: node --test web/voice/parser.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseCommand, hasWakeWord, stripWakeWord, parseLlmReply } from "./parser.js";

const state = {
  garage: { open: false, distanceCm: 42.4, autoMode: true },
  window: { open: true, raining: false },
  lights: { led1: true, led2: false, led3: true },
  fire: { detected: false, buzzerOn: false },
  status: { online: true },
};
const act = (s) => parseCommand(s, state).actions;
const reply = (s) => parseCommand(s, state).reply;

test("garage and clothes line", () => {
  assert.deepEqual(act("open the garage door"), { garageOpen: true });
  assert.deepEqual(act("Close the garage."), { garageOpen: false });
  assert.deepEqual(act("close the clothes line"), { windowOpen: false });
  assert.deepEqual(act("open the window"), { windowOpen: true });
  assert.deepEqual(act("it's raining outside, close the clothes line"), { windowOpen: false });
});

test("fan is mobile-only on the web", () => {
  const r = parseCommand("turn on the fan", state);
  assert.deepEqual(r.actions, {});
  assert.equal(r.reply, "The fan can only be controlled from the mobile app.");
  assert.equal(r.understood, true);
});

test("general control lights 1-3", () => {
  assert.deepEqual(act("turn on light 1"), { led1: true });
  assert.deepEqual(act("switch off light two"), { led2: false });
  assert.deepEqual(act("turn the third light off"), { led3: false });
  assert.deepEqual(act("lights off"), { led1: false, led2: false, led3: false });
  assert.deepEqual(act("turn on lights 1 and 3"), { led1: true, led3: true });
});

test("compound, alarm, auto", () => {
  assert.deepEqual(act("open the garage and the clothes line"), { garageOpen: true, windowOpen: true });
  assert.deepEqual(act("silence the alarm"), { silenceBuzzer: true });
  assert.deepEqual(act("turn off auto mode"), { autoMode: false });
  assert.equal(reply("open the garage and turn on light 1"), "Opening the garage and turning on light 1.");
  assert.equal(reply("turn off lights 1 and 2"), "Turning off lights 1 and 2.");
});

test("questions", () => {
  assert.equal(reply("is the garage open?"), "The garage is closed.");
  assert.equal(reply("which lights are on"), "Lights 1 and 3 are on.");
  assert.equal(reply("how far is the car"), "The garage sensor reads 42 centimetres.");
  assert.equal(reply("is it raining?"), "No rain right now. The clothes line is open.");
});

test("half-understood sentences are not confident", () => {
  const r = parseCommand("it's getting dark outside, turn on light 2", state);
  assert.deepEqual(r.actions, { led2: true });
  assert.equal(r.confident, false);
  assert.equal(parseCommand("I'm home, turn on light 1", state).confident, true);
});

test("fallback, wake word, llm", () => {
  assert.equal(parseCommand("play some jazz music", state).understood, false);
  assert.ok(hasWakeWord("Hey Home open the garage"));
  assert.ok(!hasWakeWord("open the garage"));
  assert.equal(stripWakeWord("OK home, open the garage"), "open the garage");
  const r = parseLlmReply('x {"actions":[{"key":"led3","value":true},{"key":"led4","value":true},{"key":"evil","value":true}],"reply":"Hi"}');
  assert.deepEqual(r.actions, { led3: true }); // led4 no longer exists
});
