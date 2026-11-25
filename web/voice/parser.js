// Offline, rule-based intent parser for the Calm Hills voice agent.
// Port of mobile/smart_home_app/lib/voice/command_parser.dart — keep in sync.

export const COMMAND_KEYS = new Set([
  "garageOpen", "windowOpen", "led1", "led2", "led3", "autoMode", "silenceBuzzer",
]);

// The fan is controlled from the mobile app only (the Dart parser handles it).
const FAN = /\b(fans?|ventilation|ventilator)\b/;
export const FAN_ONLY_ON_PHONE = "The fan can only be controlled from the mobile app.";

// The three "general control lights".
export const LIGHT_NAMES = { led1: "light 1", led2: "light 2", led3: "light 3" };
const ALL_LIGHTS = ["led1", "led2", "led3"];

/** "light 2" or "lights 1 and 3" */
function lightList(keys) {
  const nums = keys.map((k) => k.slice(3));
  return nums.length === 1 ? `light ${nums[0]}` : `lights ${nums.slice(0, -1).join(", ")} and ${nums[nums.length - 1]}`;
}

const WAKE = /^(?:(?:hey|hi|okay|ok|hello)\s+)?(?:home|house|calm hills)\b[\s,]*/;

export const normalize = (t) =>
  t.toLowerCase().replace(/[^a-z0-9'\s,]/g, " ").replace(/\s+/g, " ").trim();

export const hasWakeWord = (t) => WAKE.test(normalize(t));
export const stripWakeWord = (t) => normalize(t).replace(WAKE, "");

function verbOf(c) {
  if (/\b(close|shut|lock|lower|off|kill|disable|deactivate|stop|silence|mute|quiet|hush)\b/.test(c)) return "off";
  if (/\b(open|unlock|raise|lift|on|light up|enable|activate|start|brighten|bright|brighter)\b/.test(c)) return "on";
  return null;
}

function devicesOf(c) {
  const out = [];
  const add = (k) => { if (!out.includes(k)) out.push(k); };
  if (/\bgarage\b/.test(c)) add("garageOpen");
  if (/\b(clothes ?lines?|washing lines?|laundry|clothes|windows?|roof|rain cover)\b/.test(c)) add("windowOpen");

  const allLights =
    /\b(all|every|everything|all the|whole house)\b.*\b(lights?|leds?|lamps?)\b|\b(lights?|leds?|lamps?)\b.*\b(everywhere|all)\b/.test(c);
  if (allLights) ALL_LIGHTS.forEach(add);
  else {
    // "light 1", "light one", "first light", "led 1"; a bare number in a list
    // ("lights 1 and 3" splits into "lights 1" + "3") also counts.
    const words = { 1: "one|first", 2: "two|second", 3: "three|third" };
    for (const [n, w] of Object.entries(words)) {
      const named = new RegExp(`\\b((lights?|lamps?|leds?) ?(${n}|${w})|(${w}) (light|lamp))\\b`);
      const bare = new RegExp(`^(the )?(${n}|${w})( lights?)?$`);
      if (named.test(c) || bare.test(c.trim())) add(`led${n}`);
    }
  }
  if (/\b(auto mode|automatic|auto|ultrasonic|sensor mode)\b/.test(c)) add("autoMode");
  if (/\b(silence|mute|quiet|buzzer|alarm|siren)\b/.test(c)) add("silenceBuzzer");
  return out;
}

const isQuestion = (c) =>
  /^(is|are|was|what|what's|whats|how|which|tell me|give me|any|do i|did i|status|report)\b|\bstatus\b|\?$/.test(c);
const startsWithCommand = (c) =>
  /^(open|close|shut|turn|switch|lock|unlock|silence|mute|enable|disable|let)\b/.test(c);

const joinList = (xs) =>
  xs.length === 1 ? xs[0] : `${xs.slice(0, -1).join(", ")} and ${xs[xs.length - 1]}`;

export function describeActions(actions) {
  const parts = [];
  const on = [], off = [];
  for (const [k, v] of Object.entries(actions)) {
    if (k === "garageOpen") parts.push(v ? "opening the garage" : "closing the garage");
    else if (k === "windowOpen") parts.push(v ? "opening the clothes line" : "closing the clothes line");
    else if (k === "autoMode") parts.push(v ? "turning auto mode on" : "turning auto mode off");
    else if (k === "silenceBuzzer") parts.push("silencing the alarm");
    else if (LIGHT_NAMES[k]) (v ? on : off).push(k);
  }
  const lights = (ks, verb) =>
    ks.length === ALL_LIGHTS.length ? `turning ${verb} all the lights` : `turning ${verb} ${lightList(ks)}`;
  if (on.length) parts.push(lights(on, "on"));
  if (off.length) parts.push(lights(off, "off"));
  if (!parts.length) return "Done.";
  const s = joinList(parts);
  return s[0].toUpperCase() + s.slice(1) + ".";
}

export function answerQuestion(text, state) {
  const garage = state.garage || {}, win = state.window || {}, lights = state.lights || {};
  const fire = state.fire || {}, status = state.status || {};
  const openWord = (v) => (v === true ? "open" : "closed");
  const lightsSummary = () => {
    const on = ALL_LIGHTS.filter((k) => lights[k] === true);
    if (!on.length) return "All lights are off.";
    if (on.length === ALL_LIGHTS.length) return "All lights are on.";
    const list = lightList(on);
    return `${list[0].toUpperCase()}${list.slice(1)} ${on.length > 1 ? "are" : "is"} on.`;
  };
  if (/\b(fire|flame|smoke|alarm|buzzer)\b/.test(text))
    return fire.detected === true
      ? `Warning: fire is detected! The buzzer is ${fire.buzzerOn === true ? "sounding" : "silenced"}.`
      : "No fire detected. Everything is safe.";
  if (/\b(distance|far|car|parked|ultrasonic)\b/.test(text))
    return typeof garage.distanceCm === "number"
      ? `The garage sensor reads ${garage.distanceCm.toFixed(0)} centimetres.`
      : "I have no distance reading yet.";
  if (/\bgarage\b/.test(text)) return `The garage is ${openWord(garage.open)}.`;
  if (/\b(rain|raining|wet|weather)\b/.test(text))
    return win.raining === true
      ? "It's raining, so the clothes line is closed."
      : `No rain right now. The clothes line is ${openWord(win.open)}.`;
  if (/\b(clothes ?lines?|washing lines?|laundry|clothes|windows?|roof)\b/.test(text))
    return `The clothes line is ${openWord(win.open)}.`;
  if (FAN.test(text)) return FAN_ONLY_ON_PHONE;
  if (/\b(lights?|lamps?|leds?)\b/.test(text)) return lightsSummary();
  if (/\b(online|connected|esp|device|wifi)\b/.test(text))
    return status.online === true ? "The ESP32 is online." : "The ESP32 is offline.";
  if (/\b(status|everything|house|home|report|going on)\b/.test(text))
    return `Garage ${openWord(garage.open)}, clothes line ${openWord(win.open)}${win.raining === true ? " (raining)" : ""}. ${lightsSummary()} ${
      fire.detected === true ? "Fire detected!" : "No fire."
    }`;
  return null;
}

/** @returns {{actions: Record<string, boolean>, reply: string, understood: boolean}} */
export function parseCommand(utterance, state = {}) {
  const text = stripWakeWord(utterance);
  if (!text) return { actions: {}, reply: "Yes? Tell me what to do.", understood: true };
  if (FAN.test(text) && !/\b(lights?|garage|windows?|roof)\b/.test(text))
    return { actions: {}, reply: FAN_ONLY_ON_PHONE, understood: true, confident: true };

  if (isQuestion(text) && !startsWithCommand(text)) {
    const answer = answerQuestion(text, state);
    if (answer) return { actions: {}, reply: answer, understood: true };
  }

  const clauses = text
    .split(/\s*(?:,|\band then\b|\bthen\b|\band\b|\balso\b|\bplus\b)\s*/)
    .filter(Boolean);
  const actions = {};
  let confident = true;
  let lastVerb = null;
  for (const clause of clauses) {
    let devices = devicesOf(clause);
    const verb = verbOf(clause) ?? lastVerb;
    if (!devices.length && /\b(lights?|lamps?|leds?)\b/.test(clause)) devices = [...ALL_LIGHTS];
    if (!devices.length || !verb) {
      // Half understood: let the LLM take it when one is available.
      if (!FILLER.test(clause)) confident = false;
      continue;
    }
    lastVerb = verb;
    for (const d of devices) actions[d] = d === "silenceBuzzer" ? true : verb === "on";
  }

  if (!Object.keys(actions).length)
    return { actions: {}, reply: `Sorry, I didn't understand "${text}".`, understood: false };
  return { actions, reply: describeActions(actions), understood: true, confident };
}

const FILLER =
  /^(please|thanks|thank you|now|quickly|for me|hi|hello|hey|okay|ok|(i'm|im|i am|we're|were|we are) (home|back|here)|i'm back|welcome)$/;

/** Validates an LLM JSON reply; returns null when unusable. */
export function parseLlmReply(content) {
  const s = content.indexOf("{"), e = content.lastIndexOf("}");
  if (s < 0 || e <= s) {
    // Plain prose: speak it, but never act on it.
    const text = content.trim();
    return text ? { actions: {}, reply: text, understood: true } : null;
  }
  try {
    const obj = JSON.parse(content.slice(s, e + 1));
    const actions = {};
    for (const a of obj.actions || []) {
      if (a && COMMAND_KEYS.has(a.key) && typeof a.value === "boolean") actions[a.key] = a.value;
    }
    const reply = String(obj.reply ?? "").trim();
    return { actions, reply: reply || describeActions(actions), understood: true };
  } catch {
    return null;
  }
}
