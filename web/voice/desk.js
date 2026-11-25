// Voice desk: Web Speech API listening + speech replies + hybrid brain
// (offline parser first, optional LLM through the local proxy in tools/voice-proxy.mjs).
import { parseCommand, hasWakeWord, stripWakeWord, parseLlmReply } from "./parser.js";

const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
const AI_KEY = "calmhills.aiEndpoint";
const DEFAULT_AI = "http://localhost:8787";
const WAKE_WINDOW_MS = 8000;

const $ = (id) => document.getElementById(id);

export class VoiceDesk {
  /**
   * @param {{getState: () => object, apply: (actions: object, log: object) => Promise<void>}} opts
   */
  constructor({ getState, apply }) {
    this.getState = getState;
    this.apply = apply;
    this.mode = "tap";
    this.phase = "idle"; // idle | listening | thinking | speaking
    this.muted = false;
    this.history = [];
    this.awakeUntil = 0;
    this.remoteSeen = undefined;
    this.ai = { ready: false, model: "", endpoint: safeGet(AI_KEY) || DEFAULT_AI };

    this.el = {
      mic: $("micBtn"),
      status: $("voiceStatus"),
      ledger: $("ledger"),
      interim: $("interim"),
      form: $("voiceForm"),
      text: $("voiceText"),
      mute: $("muteBtn"),
      brain: $("brainStatus"),
      modes: [...document.querySelectorAll(".mode [data-mode]")],
    };

    this.setupRecognition();
    this.bind();
    // Keep the newest turn in view whenever the ledger resizes (e.g. layout change).
    new ResizeObserver(() => this.scrollLedger()).observe(this.el.ledger);
    this.probeAi();
  }

  /* ── Setup ─────────────────────────────────────────── */

  setupRecognition() {
    if (!Recognition) {
      this.el.mic.disabled = true;
      this.el.modes.forEach((b) => (b.disabled = true));
      this.setStatus("Voice needs Chrome or Edge. You can type commands below.");
      return;
    }
    const rec = new Recognition();
    rec.lang = "en-US";
    rec.interimResults = true;
    rec.maxAlternatives = 1;
    rec.onstart = () => this.setPhase("listening");
    rec.onresult = (e) => this.onResult(e);
    rec.onerror = (e) => this.onError(e);
    rec.onend = () => {
      this.el.interim.hidden = true;
      if (this.phase === "listening") this.setPhase("idle");
      if (this.mode === "handsfree" && this.phase === "idle") this.startSoon();
    };
    this.rec = rec;
  }

  bind() {
    this.el.mic.addEventListener("click", () => {
      if (this.phase === "listening") this.stop();
      else this.listen();
    });
    this.el.modes.forEach((b) =>
      b.addEventListener("click", () => this.setMode(b.dataset.mode))
    );
    this.el.form.addEventListener("submit", (e) => {
      e.preventDefault();
      const t = this.el.text.value;
      this.el.text.value = "";
      this.handle(t);
    });
    this.el.mute.addEventListener("click", () => {
      this.muted = !this.muted;
      if (this.muted) window.speechSynthesis?.cancel();
      this.el.mute.setAttribute("aria-pressed", String(this.muted));
      const label = this.muted ? "Unmute spoken replies" : "Mute spoken replies";
      this.el.mute.setAttribute("aria-label", label);
      this.el.mute.title = label;
      this.el.mute.querySelector("use").setAttribute("href", this.muted ? "#i-muted" : "#i-sound");
    });
  }

  async probeAi() {
    try {
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 1500);
      const res = await fetch(`${this.ai.endpoint}/health`, { signal: ctrl.signal });
      clearTimeout(t);
      const body = await res.json();
      this.ai.ready = res.ok && body.ok === true;
      this.ai.model = body.model || "";
    } catch {
      this.ai.ready = false;
    }
    this.el.brain.textContent = this.ai.ready
      ? "Smart replies on: ask in your own words"
      : "Direct commands only";
    this.el.brain.title = this.ai.ready
      ? `AI model: ${this.ai.model}`
      : "Start tools/voice-proxy.mjs on this computer to understand free-form requests.";
  }

  /* ── Listening ─────────────────────────────────────── */

  setMode(mode) {
    this.mode = mode;
    this.el.modes.forEach((b) => b.setAttribute("aria-checked", String(b.dataset.mode === mode)));
    if (!this.rec) return;
    this.rec.continuous = mode === "handsfree";
    this.stop();
    if (mode === "handsfree") this.startSoon(50);
    else this.setStatus("Ring the bell and speak");
  }

  listen() {
    if (!this.rec || this.phase === "thinking" || this.phase === "speaking") return;
    window.speechSynthesis?.cancel();
    try {
      this.rec.start();
    } catch {
      /* already started */
    }
  }

  startSoon(ms = 400) {
    clearTimeout(this.restartTimer);
    this.restartTimer = setTimeout(() => {
      if (this.mode === "handsfree" && this.phase === "idle") this.listen();
    }, ms);
  }

  stop() {
    clearTimeout(this.restartTimer);
    try {
      this.rec?.abort();
    } catch {
      /* not running */
    }
    if (this.phase === "listening") this.setPhase("idle");
  }

  onResult(e) {
    let interim = "";
    for (let i = e.resultIndex; i < e.results.length; i++) {
      const r = e.results[i];
      const text = r[0].transcript;
      if (!r.isFinal) {
        interim += text;
        continue;
      }
      this.el.interim.hidden = true;
      this.onFinal(text);
    }
    if (interim) {
      this.el.interim.textContent = `“${interim.trim()}”`;
      this.el.interim.hidden = false;
    }
  }

  onFinal(text) {
    const said = text.trim();
    if (!said) return;
    if (this.mode === "handsfree") {
      const woke = hasWakeWord(said);
      const inWindow = Date.now() < this.awakeUntil;
      if (!woke && !inWindow) return; // not addressed to us
      if (woke && !stripWakeWord(said)) {
        this.awakeUntil = Date.now() + WAKE_WINDOW_MS;
        this.say("Yes?");
        this.setStatus("Listening for your command…");
        return;
      }
      this.awakeUntil = 0;
    }
    this.handle(said);
  }

  onError(e) {
    if (e.error === "no-speech" || e.error === "aborted") return;
    if (e.error === "not-allowed" || e.error === "service-not-allowed") {
      this.mode = "tap";
      this.el.modes.forEach((b) => b.setAttribute("aria-checked", String(b.dataset.mode === "tap")));
      this.setStatus("Microphone blocked. Allow it from the address bar, then ring again.");
    } else if (e.error === "network") {
      this.setStatus("The speech service is unreachable. Type your command instead.");
    } else {
      this.setStatus(`Voice error: ${e.error}`);
    }
    this.setPhase("idle", false);
  }

  /* ── Brain ─────────────────────────────────────────── */

  async handle(text) {
    const said = (text || "").trim();
    if (!said) return;
    this.stop();
    this.addTurn(said, "user");
    this.setPhase("thinking");

    const state = this.getState();
    let result = parseCommand(said, state);
    let source = "Offline";
    if ((!result.understood || result.confident === false) && this.ai.ready) {
      const ai = await this.askAi(stripWakeWord(said), state);
      if (ai) {
        result = ai;
        source = "AI";
      } else if (result.understood) {
        // AI unreachable: keep what the offline parser understood.
      } else {
        result = { actions: {}, reply: "I couldn't reach the AI helper. Try a direct command like “open the garage”.", understood: false };
      }
    } else if (!result.understood) {
      result = { ...result, reply: `${result.reply} Try “open the garage” or “turn on light 1”.` };
    }

    let isError = !result.understood;
    try {
      await this.apply(result.actions, { text: said, reply: result.reply, source: source.toLowerCase() });
    } catch (err) {
      result = { ...result, reply: `I couldn't reach the house: ${err.message}` };
      isError = true;
    }

    this.history.push({ role: "user", content: said }, { role: "assistant", content: result.reply });
    this.history = this.history.slice(-8);
    this.addTurn(result.reply, "agent", source, isError);
    await this.say(result.reply);
    this.setPhase("idle");
    if (this.mode === "handsfree") this.startSoon();
  }

  async askAi(text, state) {
    try {
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 12000);
      const res = await fetch(`${this.ai.endpoint}/agent`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, state: stripVoice(state), history: this.history }),
        signal: ctrl.signal,
      });
      clearTimeout(t);
      if (!res.ok) return null;
      const body = await res.json();
      return parseLlmReply(body.content || "");
    } catch {
      return null;
    }
  }

  /* ── Output ────────────────────────────────────────── */

  say(text) {
    const synth = window.speechSynthesis;
    if (this.muted || !synth || !text) return Promise.resolve();
    return new Promise((resolve) => {
      synth.cancel();
      const u = new SpeechSynthesisUtterance(text);
      u.lang = "en-US";
      u.rate = 1.02;
      const done = () => resolve();
      u.onend = done;
      u.onerror = done;
      this.setPhase("speaking");
      synth.speak(u);
      setTimeout(done, 15000); // never hang the loop on a stuck voice
    });
  }

  addTurn(text, who, source, isError = false) {
    const empty = this.el.ledger.querySelector(".ledger-empty");
    if (empty) empty.remove();
    const li = document.createElement("li");
    li.className = who === "user" ? "from-user" : "from-agent";
    if (isError) li.classList.add("is-error");
    li.textContent = text;
    if (source) {
      const s = document.createElement("small");
      s.textContent = source;
      li.append(s);
    }
    this.el.ledger.append(li);
    while (this.el.ledger.children.length > 40) this.el.ledger.firstElementChild.remove();
    this.scrollLedger();
  }

  scrollLedger() {
    this.el.ledger.scrollTop = this.el.ledger.scrollHeight;
  }

  /** Shows voice commands spoken on another device (e.g. the Android app). */
  onRemoteVoice(last) {
    const at = last?.at;
    if (this.remoteSeen === undefined) {
      this.remoteSeen = at ?? null; // first snapshot: history, don't replay
      return;
    }
    if (!last || at === this.remoteSeen || last.device === "web") {
      this.remoteSeen = at ?? this.remoteSeen;
      return;
    }
    this.remoteSeen = at;
    const from = last.device === "android" ? "phone" : last.device || "another device";
    this.addTurn(last.text, "user", `Said on the ${from}`);
    this.addTurn(last.reply, "agent", last.source === "ai" ? "AI" : "Offline");
  }

  setPhase(phase, updateStatus = true) {
    this.phase = phase;
    const mic = this.el.mic;
    mic.classList.toggle("is-listening", phase === "listening");
    mic.classList.toggle("is-thinking", phase === "thinking");
    const listening = phase === "listening";
    mic.setAttribute("aria-label", listening ? "Stop listening" : "Start listening");
    mic.querySelector("use").setAttribute("href", listening ? "#i-stop" : "#i-mic");
    if (!updateStatus) return;
    const hf = this.mode === "handsfree";
    this.setStatus(
      {
        listening: hf ? "Listening for “Hey Home…”" : "Listening…",
        thinking: "Working on it…",
        speaking: "Replying…",
        idle: hf ? "Hands-free is on" : "Ring the bell and speak",
      }[phase]
    );
  }

  setStatus(text) {
    this.el.status.textContent = text;
  }
}

function stripVoice(state) {
  const { voice, commands, ...rest } = state || {};
  return rest;
}

function safeGet(k) {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
}
