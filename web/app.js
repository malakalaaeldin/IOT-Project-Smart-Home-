import { initializeApp } from "https://www.gstatic.com/firebasejs/11.6.0/firebase-app.js";
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.6.0/firebase-auth.js";
import {
  getDatabase,
  ref,
  onValue,
  update,
  serverTimestamp,
} from "https://www.gstatic.com/firebasejs/11.6.0/firebase-database.js";
import { firebaseConfig } from "./firebase-config.js";
import { VoiceDesk } from "./voice/desk.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getDatabase(app);

const $ = (id) => document.getElementById(id);
const authPanel = $("authPanel");
const dashPanel = $("dashPanel");
const authError = $("authError");
const bar = $("bar");
const deviceStatus = $("deviceStatus");
const logoutBtn = $("logoutBtn");
const fireBanner = $("fireBanner");
const boardNotice = $("boardNotice");
const tags = [...document.querySelectorAll(".tag[data-key]")];
const alarmTag = $("alarmTag");

const DETECTION_CM = 15; // firmware/esp32_smart_home: DETECTION_CM
const GAUGE_MAX_CM = 200;
const PENDING_TIMEOUT_MS = 6000;

let home = {};
let unsubHome = null;

// The firmware never writes online=false when it loses power, so trust the
// heartbeat instead: it bumps status/lastSeen every 5 s (STATUS_INTERVAL_MS).
const STALE_MS = 20000;
const heartbeat = { value: undefined, changedAt: 0, since: 0 };
function trackHeartbeat(lastSeen) {
  if (lastSeen !== heartbeat.value) {
    if (heartbeat.value !== undefined) heartbeat.changedAt = Date.now();
    heartbeat.value = lastSeen;
  }
}
/** "online" | "checking" | "offline" */
function liveness() {
  if (home.status?.online !== true) return "offline";
  if (Date.now() - heartbeat.changedAt < STALE_MS) return "online";
  return Date.now() - heartbeat.since < STALE_MS ? "checking" : "offline";
}
const pending = new Map(); // key -> { value, timer }

const get = (obj, path) => path.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);

/* ── Commands ─────────────────────────────────────────── */

/**
 * Writes commands in one atomic update. Manual garage control turns auto mode
 * off, exactly like the firmware expects.
 */
export async function sendCommands(actions, extra = {}) {
  const updates = {};
  for (const [k, v] of Object.entries(actions)) updates[`commands/${k}`] = v;
  if ("garageOpen" in actions && !("autoMode" in actions)) updates["commands/autoMode"] = false;
  Object.assign(updates, extra);
  await update(ref(db, "smartHome"), updates);
  for (const [k, v] of Object.entries(actions)) markPending(k, v);
}

function markPending(key, value) {
  const tag = tags.find((t) => t.dataset.key === key);
  if (!tag) return;
  const current = readTagState(tag);
  if (current === value) return; // already there
  clearTimeout(pending.get(key)?.timer);
  const timer = setTimeout(() => {
    // Still unconfirmed: the tag keeps saying so for as long as the notice shows.
    tag.classList.replace("is-pending", "is-waiting");
    updateWaitingNotice();
  }, PENDING_TIMEOUT_MS);
  pending.set(key, { value, timer });
  tag.classList.remove("is-waiting");
  tag.classList.add("is-pending");
  tag.setAttribute("aria-busy", "true");
}

function clearPending(tag) {
  const p = pending.get(tag.dataset.key);
  if (p) clearTimeout(p.timer);
  pending.delete(tag.dataset.key);
  tag.classList.remove("is-pending", "is-waiting");
  tag.removeAttribute("aria-busy");
  updateWaitingNotice();
}

function updateWaitingNotice() {
  const waiting = tags.filter((t) => t.classList.contains("is-waiting"));
  if (!waiting.length) {
    if (boardNotice.dataset.kind === "waiting") showNotice("");
    return;
  }
  const names = waiting.map((t) => `“${t.querySelector(".tag-name").textContent}”`).join(", ");
  showNotice(
    liveness() === "online"
      ? `The house hasn't confirmed ${names} yet. It will apply when the ESP32 reads the command.`
      : `The ESP32 isn't responding, so ${names} ${waiting.length > 1 ? "are" : "is"} waiting. Commands apply when it reconnects.`,
    "waiting"
  );
}

function showNotice(text, kind = "info") {
  boardNotice.textContent = text;
  boardNotice.dataset.kind = kind;
  boardNotice.hidden = !text;
}

function readTagState(tag) {
  const v = get(home, tag.dataset.state);
  if (v === undefined && tag.dataset.default === "true") return true;
  return v === true;
}

/* ── Rendering ────────────────────────────────────────── */

function renderTag(tag) {
  const on = readTagState(tag);
  const was = tag.classList.contains("is-on");
  tag.classList.toggle("is-on", on);
  tag.setAttribute("aria-checked", String(on));
  tag.querySelector(".tag-state").textContent = on ? tag.dataset.on : tag.dataset.off;
  const name = tag.querySelector(".tag-name").textContent;
  tag.setAttribute("aria-label", `${name}: ${on ? tag.dataset.on : tag.dataset.off}`);
  if (was !== on && tag.dataset.rendered) swing(tag);
  tag.dataset.rendered = "1";
  const p = pending.get(tag.dataset.key);
  if (p && p.value === on) clearPending(tag);
}

function renderPill(live, status = home.status || {}) {
  deviceStatus.textContent = {
    online: `ESP32 online${typeof status.wifiRssi === "number" ? ` · ${status.wifiRssi} dBm` : ""}`,
    checking: "Checking ESP32…",
    offline: status.online === true ? "ESP32 not responding" : "ESP32 offline",
  }[live];
  deviceStatus.className = `pill ${live === "online" ? "pill-online" : "pill-offline"}`;
  deviceStatus.title =
    live === "offline" && status.online === true
      ? "No heartbeat for 20 seconds. The board may be unplugged or off Wi-Fi."
      : "";
}

function swing(el) {
  el.classList.remove("is-swinging");
  void el.offsetWidth;
  el.classList.add("is-swinging");
}

function render() {
  const status = home.status || {};
  const garage = home.garage || {};
  const fire = home.fire || {};
  const lights = home.lights || {};
  const live = liveness();
  const online = live === "online";
  renderPill(live, status);

  tags.forEach(renderTag);

  // Alarm tag: only actionable while the buzzer sounds.
  const detected = fire.detected === true;
  const buzzing = fire.buzzerOn === true;
  alarmTag.disabled = !buzzing;
  alarmTag.classList.toggle("is-alarm", detected);
  alarmTag.querySelector(".tag-state").textContent = buzzing ? "Sounding · tap to silence" : detected ? "Silenced" : "Quiet";

  // Window: the ESP32 refuses to open it while it rains.
  const win = home.window || {};
  const raining = win.raining === true;
  const windowTag = $("windowTag");
  windowTag.disabled = raining && win.open !== true;
  if (raining && win.open !== true) windowTag.querySelector(".tag-state").textContent = "Closed · raining";
  $("rainValue").textContent = raining ? "Raining" : "Dry";
  $("rainNote").textContent = raining
    ? "The window closed itself and stays shut until it's dry."
    : "The window closes by itself when it rains.";
  $("rainCard").classList.toggle("is-rain", raining);

  const lit = ["led1", "led2", "led3"].filter((k) => lights[k] === true).length;
  const open = [garage.open === true && "garage", win.open === true && "window"].filter(Boolean);
  $("boardSummary").textContent =
    `${open.length === 0 ? "Garage and window closed" : `${open.join(" and ")} open`.replace(/^./, (c) => c.toUpperCase())} · ` +
    `${lit === 0 ? "lights off" : `${lit} of 3 lights on`}`;
  updateWaitingNotice();

  // Garage sensor
  const d = garage.distanceCm;
  const gauge = document.querySelector(".gauge");
  if (typeof d === "number" && d > 0) {
    $("distanceValue").textContent = d.toFixed(1);
    $("distanceBar").style.width = `${Math.min(100, (d / GAUGE_MAX_CM) * 100)}%`;
    gauge.classList.toggle("is-near", d <= DETECTION_CM);
    $("distanceNote").textContent =
      garage.autoMode !== false
        ? d <= DETECTION_CM
          ? "Car detected. Auto mode is opening the garage."
          : `Auto mode opens the garage at ${DETECTION_CM} cm or closer.`
        : "Auto mode is off. The garage only moves on command.";
  } else {
    $("distanceValue").textContent = "—";
    $("distanceBar").style.width = "0";
    gauge.classList.remove("is-near");
    $("distanceNote").textContent = online ? "Waiting for a sensor reading." : "No reading while the ESP32 is offline.";
  }

  // Fire
  $("fireMeta").textContent = detected ? "Flame detected" : "No flame";
  $("buzzerMeta").textContent = buzzing ? "Buzzer sounding" : detected ? "Buzzer silenced" : "Buzzer off";
  $("fireCard").classList.toggle("is-fire", detected);
  fireBanner.hidden = !detected;
  $("fireBannerText").textContent = buzzing ? "The buzzer is sounding." : "The buzzer is silenced. Check the house.";
  $("silenceBtn").hidden = !buzzing;
  bar.classList.toggle("is-fire", detected);
}

/* ── Controls ─────────────────────────────────────────── */

tags.forEach((tag) => {
  tag.addEventListener("click", async () => {
    const next = !readTagState(tag);
    try {
      await sendCommands({ [tag.dataset.key]: next });
    } catch (err) {
      showNotice(`Couldn't send the command: ${err.message}`);
    }
  });
});

const silence = () => sendCommands({ silenceBuzzer: true }).catch((e) => showNotice(e.message));
alarmTag.addEventListener("click", silence);
$("silenceBtn").addEventListener("click", silence);

/* ── Voice ────────────────────────────────────────────── */

const desk = new VoiceDesk({
  getState: () => home,
  apply: (actions, log) =>
    sendCommands(actions, {
      "voice/last": { ...log, actions, device: "web", at: serverTimestamp() },
    }),
});

/* ── Auth ─────────────────────────────────────────────── */

function showError(message) {
  authError.hidden = !message;
  authError.textContent = message || "";
}

function friendlyAuthError(err) {
  const code = err?.code || "";
  if (code.includes("invalid-credential") || code.includes("wrong-password") || code.includes("user-not-found"))
    return "That email and password don't match an account. Check them, or create an account.";
  if (code.includes("email-already-in-use")) return "An account with this email already exists. Sign in instead.";
  if (code.includes("weak-password")) return "Choose a password of at least 6 characters.";
  if (code.includes("invalid-email")) return "Enter a valid email address.";
  if (code.includes("network")) return "Can't reach Firebase. Check your internet connection.";
  return err?.message || "Something went wrong. Try again.";
}

async function withBusy(fn) {
  const buttons = [$("signInBtn"), $("registerBtn")];
  buttons.forEach((b) => (b.disabled = true));
  showError("");
  try {
    await fn();
  } catch (err) {
    showError(friendlyAuthError(err));
  } finally {
    buttons.forEach((b) => (b.disabled = false));
  }
}

$("loginForm").addEventListener("submit", (e) => {
  e.preventDefault();
  withBusy(() => signInWithEmailAndPassword(auth, $("email").value.trim(), $("password").value));
});

$("registerBtn").addEventListener("click", () => {
  if (!$("loginForm").reportValidity()) return;
  withBusy(() => createUserWithEmailAndPassword(auth, $("email").value.trim(), $("password").value));
});

logoutBtn.addEventListener("click", () => signOut(auth));

// Re-evaluate liveness between snapshots (a dead board sends none).
setInterval(() => {
  if (unsubHome) render();
}, 5000);

onAuthStateChanged(auth, (user) => {
  const signedIn = Boolean(user);
  authPanel.hidden = signedIn;
  dashPanel.hidden = !signedIn;
  logoutBtn.hidden = !signedIn;
  if (unsubHome) unsubHome();
  unsubHome = null;
  if (signedIn) {
    heartbeat.since = Date.now();
    heartbeat.value = undefined;
    heartbeat.changedAt = 0;
    unsubHome = onValue(ref(db, "smartHome"), (snap) => {
      home = snap.val() || {};
      trackHeartbeat(home.status?.lastSeen);
      render();
      desk.onRemoteVoice(home.voice?.last);
    });
  } else {
    desk.stop();
  }
});
