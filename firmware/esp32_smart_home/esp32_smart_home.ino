/*
 * Calm Hills Smart Home — unified ESP32 firmware
 * Board: ESP32S 38-pin DevKit (WIFI + Bluetooth)
 *
 * Devices:
 *   - Garage door servo + HC-SR04 ultrasonic (auto-open when a car is close)
 *   - Window/roof servo + rain sensor (closes automatically when it rains)
 *   - Fan on a relay module (controlled from the mobile app)
 *   - 3 general control lights (LEDs), flame sensor + buzzer
 *
 * Libraries (Arduino Library Manager):
 *   - ESP32Servo
 *   - Firebase ESP Client by Mobizt (Firebase_ESP_Client)
 *
 * Setup:
 *   1. Edit WIFI_SSID / WIFI_PASSWORD below (2.4 GHz only)
 *   2. Board: ESP32 Dev Module · Serial 115200
 *
 * Firebase layout (/smartHome):
 *   commands/{garageOpen, windowOpen, fanOn, led1..led3, autoMode, silenceBuzzer}  <- apps write
 *   garage/{open, autoMode, distanceCm}, window/{open, raining}, fan/{on},
 *   lights/{led1..led3}, fire/{detected, buzzerOn}, status/{online, wifiRssi, lastSeen} <- ESP32 writes
 *
 * How it stays responsive (why the unit tests worked but the full system didn't):
 *   - The loop never waits on the network for long. Sensors are read every pass.
 *   - The Firebase stream callback only raises a flag. Commands are then fetched
 *     with ONE request in loop() (no Firebase calls inside the callback, which
 *     runs at the same time as loop() and corrupted the shared connection).
 *   - State is written to Firebase only when it changes; status every 5 s.
 *
 * Debugging (Serial Monitor 115200, type a letter + Enter):
 *   h help | r health report now | v live sensor readings on/off | f fetch commands now
 *   g garage open/close | w window open/close | n fan on/off | 1-3 toggle a light
 *   b buzzer beep test | a garage auto mode on/off
 */

#include <WiFi.h>
#include <ESP32Servo.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include "esp_system.h"

// ========== EDIT THESE ==========
// Wi-Fi (the ESP32 only supports 2.4 GHz networks)
#define WIFI_SSID "YOUR_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define FIREBASE_HOST "calm-hills-smart-home-default-rtdb.firebaseio.com"
#define FIREBASE_API_KEY "AIzaSyDW9RtinDZKjAPELdYUemKgEDgdH1Ihlg8"  // public web API key
// The board signs in as its own Firebase user, so the database can require login
// (project requirement: only logged-in users can view or control devices).
// Leave DEVICE_PASSWORD empty to use the old open-database token instead.
#define DEVICE_EMAIL "esp32-device@calmhills.local"
#define DEVICE_PASSWORD ""
#define FIREBASE_LEGACY_TOKEN "calm-hills-lab-token"
// ================================

// Pins — ESP32S 38-pin DevKit (see docs/WIRING.md)
#define TRIG_PIN 5
#define ECHO_PIN 18
#define GARAGE_SERVO_PIN 19
#define WINDOW_SERVO_PIN 23   // was the front-door servo
#define RAIN_SENSOR_PIN 4     // rain plate / module DO (was the IR sensor)
#define FAN_RELAY_PIN 13      // relay module IN
#define FLAME_SENSOR_PIN 34
#define BUZZER_PIN 25
#define LED1_PIN 26
#define LED2_PIN 27
#define LED3_PIN 32
// GPIO 33 (old porch light) is free: only 3 general control lights now

// ---- Hardware options (tested with the unit-test sketches) ----
const bool RAIN_ACTIVE_LOW = true;        // rain plate: water pulls the pin LOW
const bool FAN_RELAY_ACTIVE_LOW = true;   // most relay boards: IN LOW = ON
const bool FLAME_ACTIVE_LOW = false;      // our flame module: DO HIGH = flame
const bool BUZZER_ACTIVE_LOW = false;     // 2-pin active buzzer: HIGH = sound

// Behaviour
const bool SELF_TEST_AT_BOOT = true;      // beep once + swing the window servo at start-up

// ---- Automation settings: DEFAULTS only. The live values are read from
// /smartHome/settings every 10 s, so they can be changed from the mobile app.
int detectCm = 15;                        // settings/garageDetectCm
unsigned long garageCloseMs = 3000;       // settings/garageCloseDelaySec
bool windowFollowsRain = true;            // settings/clothesLineFollowsRain
                                          //   true: wet -> close, dry -> open
                                          //   false: only closes on rain
unsigned long historyEveryMs = 30000;     // settings/historyIntervalSec

// Servo angles
const int OPEN_ANGLE = 90;                // garage
const int CLOSED_ANGLE = 0;
const int WINDOW_OPEN_ANGLE = 0;          // window is mounted the other way round
const int WINDOW_CLOSED_ANGLE = 90;

// Timing
const unsigned long SETTINGS_EVERY_MS = 10000;
const unsigned long RAIN_DEBOUNCE_MS = 1500;
const unsigned long FLAME_CONFIRM_MS = 300;
const unsigned long ULTRASONIC_EVERY_MS = 100;
const unsigned long STATUS_INTERVAL_MS = 5000;
const unsigned long CMD_BACKUP_FETCH_MS = 2000;   // re-read commands even without a stream event
const unsigned long WIFI_RETRY_MS = 10000;
const unsigned long HEALTH_EVERY_MS = 10000;
const unsigned long LIVE_EVERY_MS = 1000;

Servo garageServo;
Servo windowServo;

FirebaseData fbdo;     // reads (commands) + seed, used ONLY from loop()
FirebaseData fbWrite;  // async writes get their own connection so replies never mix with reads
FirebaseData stream;   // stream on /commands
FirebaseAuth auth;
FirebaseConfig config;
String basePath = "/smartHome";

// ---- House state ----
bool garageOpen = false;
bool windowOpen = false;
bool raining = false;
bool fanOn = false;
bool autoMode = true;
bool fireDetected = false;
bool buzzerOn = false;
bool silenceBuzzer = false;
const int N_LIGHTS = 3;  // general control lights 1-3
bool leds[N_LIGHTS] = {false, false, false};
const int LED_PINS[N_LIGHTS] = {LED1_PIN, LED2_PIN, LED3_PIN};

unsigned long carLeftTime = 0;
float lastDistance = -1;
unsigned long lastUltrasonicMs = 0;
bool rainReading = false;
unsigned long rainChangedAt = 0;
bool flameReading = false;
unsigned long flameChangedAt = 0;

// ---- Commands: last value seen (a command acts only when its value changes) ----
const char *COMMAND_KEYS[] = {"garageOpen", "windowOpen", "fanOn", "led1", "led2",
                              "led3", "silenceBuzzer", "autoMode"};
const int N_COMMANDS = 8;
bool lastCmd[N_COMMANDS] = {false, false, false, false, false, false, false, true};

// ---- Cloud / debug state ----
bool firebaseStarted = false;
volatile bool commandsDirty = true;      // set by the stream callback
volatile unsigned long streamEvents = 0;
volatile unsigned long streamTimeouts = 0;
unsigned long lastCmdFetchMs = 0;
unsigned long lastSettingsMs = 0;
unsigned long lastHistoryMs = 0;
long lastScheduleMinute = -1;
bool timeSynced = false;
unsigned long lastStatusMs = 0;
unsigned long lastWifiTryMs = 0;
unsigned long lastHealthMs = 0;
unsigned long lastLiveMs = 0;
unsigned long cmdFetches = 0, fbWritesOk = 0, fbFails = 0, wifiDrops = 0;
unsigned long loopMaxMs = 0, loopSlowCount = 0;
String lastFbError = "-";
bool liveReadings = false;
bool wasWifiConnected = false;

// =====================================================================
// Logging
// =====================================================================
void logt(const char *tag, const char *fmt, ...) {
  char buf[220];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buf, sizeof(buf), fmt, args);
  va_end(args);
  Serial.printf("[%8.2fs] [%-6s] %s\n", millis() / 1000.0, tag, buf);
}

const char *resetReason() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "power-on";
    case ESP_RST_SW: return "software restart";
    case ESP_RST_PANIC: return "CRASH (panic)";
    case ESP_RST_BROWNOUT: return "BROWNOUT (voltage dropped)";
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT: return "WATCHDOG (code got stuck)";
    case ESP_RST_EXT: return "reset button";
    default: return "other";
  }
}

// =====================================================================
// Firebase helpers (all called from loop() only)
// =====================================================================
bool cloudReady() {
  return firebaseStarted && WiFi.status() == WL_CONNECTED && Firebase.ready();
}

bool fbResult(bool ok, const String &what, FirebaseData &d = fbWrite) {
  if (ok) {
    fbWritesOk++;
  } else {
    fbFails++;
    lastFbError = d.errorReason();
    logt("FB", "FAILED %s -> %s", what.c_str(), lastFbError.c_str());
  }
  return ok;
}

// Async write: sends the value without waiting for Firebase's reply, so the
// loop isn't blocked for ~0.5 s per write (the "slow loop" warnings).
void fbSetBool(const String &path, bool v) {
  if (!cloudReady()) return;  // offline: the state is re-sent with the next status/seed
  fbResult(Firebase.RTDB.setBoolAsync(&fbWrite, basePath + path, v), "set " + path);
}

int commandIndex(const String &key) {
  for (int i = 0; i < N_COMMANDS; i++)
    if (key == COMMAND_KEYS[i]) return i;
  return -1;
}

// Keep /commands/<key> equal to what the house actually did, so the next tap
// in the app is a real change (fixes "manual open does nothing").
void syncCommand(const char *key, bool value) {
  int i = commandIndex(key);
  if (i >= 0) lastCmd[i] = value;
  fbSetBool(String("/commands/") + key, value);
}

// =====================================================================
// Devices
// =====================================================================
void setGarage(bool open, bool fromCommand, const char *why) {
  garageServo.write(open ? OPEN_ANGLE : CLOSED_ANGLE);
  garageOpen = open;
  carLeftTime = 0;
  logt("GARAGE", "%s (servo %d deg) - %s", open ? "OPEN" : "CLOSED", open ? OPEN_ANGLE : CLOSED_ANGLE, why);
  fbSetBool("/garage/open", open);
  if (!fromCommand) syncCommand("garageOpen", open);
}

void setWindow(bool open, bool fromCommand, const char *why) {
  windowServo.write(open ? WINDOW_OPEN_ANGLE : WINDOW_CLOSED_ANGLE);
  windowOpen = open;
  logt("WINDOW", "%s (servo %d deg) - %s", open ? "OPEN" : "CLOSED",
       open ? WINDOW_OPEN_ANGLE : WINDOW_CLOSED_ANGLE, why);
  fbSetBool("/window/open", open);
  if (!fromCommand) syncCommand("windowOpen", open);
}

void setFan(bool on, const char *why) {
  fanOn = on;
  bool level = FAN_RELAY_ACTIVE_LOW ? !on : on;
  digitalWrite(FAN_RELAY_PIN, level ? HIGH : LOW);
  logt("FAN", "%s (relay pin %s) - %s", on ? "ON" : "OFF", level ? "HIGH" : "LOW", why);
  fbSetBool("/fan/on", on);
}

void setLight(int idx, bool on, const char *why) {
  leds[idx] = on;
  digitalWrite(LED_PINS[idx], on ? HIGH : LOW);
  logt("LIGHT", "led%d %s - %s", idx + 1, on ? "ON" : "OFF", why);
  fbSetBool(String("/lights/led") + (idx + 1), on);
}

void setBuzzer(bool on) {
  if (on == buzzerOn) return;
  buzzerOn = on;
  bool level = BUZZER_ACTIVE_LOW ? !on : on;
  digitalWrite(BUZZER_PIN, level ? HIGH : LOW);
  logt("FIRE", "buzzer %s", on ? "ON" : "off");
  fbSetBool("/fire/buzzerOn", on);
}

void publishFire(bool detected) {
  fireDetected = detected;
  logt("FIRE", detected ? "FIRE DETECTED!" : "fire cleared");
  fbSetBool("/fire/detected", detected);
  if (detected && !silenceBuzzer) {
    setBuzzer(true);
  } else if (!detected) {
    silenceBuzzer = false;
    setBuzzer(false);
  }
}

// =====================================================================
// Commands
// =====================================================================
void handleCommand(const String &key, bool value) {
  logt("CMD", "%s = %s", key.c_str(), value ? "true" : "false");

  if (key == "garageOpen") {
    // Manual control takes the garage out of auto mode.
    if (autoMode) {
      autoMode = false;
      logt("GARAGE", "auto mode OFF (manual command)");
      syncCommand("autoMode", false);
      fbSetBool("/garage/autoMode", false);
    }
    setGarage(value, true, "app command");
  } else if (key == "windowOpen") {
    if (value && raining) {
      logt("WINDOW", "refused to open: it's raining");
      syncCommand("windowOpen", false);  // apps go back to "closed"
      if (windowOpen) setWindow(false, true, "raining");
    } else {
      setWindow(value, true, "app command");
    }
  } else if (key == "fanOn") {
    setFan(value, "app command");
  } else if (key.startsWith("led")) {
    int idx = key.substring(3).toInt() - 1;
    if (idx >= 0 && idx < N_LIGHTS) setLight(idx, value, "app command");
  } else if (key == "silenceBuzzer") {
    if (value) {
      silenceBuzzer = true;
      setBuzzer(false);
      logt("FIRE", "buzzer silenced from the app");
      syncCommand("silenceBuzzer", false);
    }
  } else if (key == "autoMode") {
    autoMode = value;
    carLeftTime = 0;
    logt("GARAGE", "auto mode %s (app command)", value ? "ON" : "OFF");
    fbSetBool("/garage/autoMode", autoMode);
  }
}

// One request for all commands (instead of 9). Values are copied out first,
// because handling a command makes new requests that reuse fbdo's buffer.
void fetchCommands(const char *why) {
  if (!cloudReady()) return;
  cmdFetches++;
  unsigned long t0 = millis();
  if (!Firebase.RTDB.getJSON(&fbdo, basePath + "/commands")) {
    fbFails++;
    lastFbError = fbdo.errorReason();
    logt("FB", "FAILED reading /commands (%s) -> %s", why, lastFbError.c_str());
    return;
  }
  bool has[N_COMMANDS];
  bool val[N_COMMANDS];
  FirebaseJson &json = fbdo.jsonObject();
  FirebaseJsonData r;
  for (int i = 0; i < N_COMMANDS; i++) {
    json.get(r, COMMAND_KEYS[i]);
    has[i] = r.success && r.type == "boolean";
    val[i] = has[i] ? r.boolValue : false;
  }
  unsigned long took = millis() - t0;
  if (took > 1500) logt("FB", "slow /commands read: %lu ms (Wi-Fi weak?)", took);

  for (int i = 0; i < N_COMMANDS; i++) {
    if (has[i] && val[i] != lastCmd[i]) {
      lastCmd[i] = val[i];
      handleCommand(COMMAND_KEYS[i], val[i]);
    }
  }
}

// ---- Automation settings (changed from the mobile app) ----
// Reads /smartHome/settings; missing values keep their defaults.
void fetchSettings() {
  if (!cloudReady()) return;
  if (!Firebase.RTDB.getJSON(&fbdo, basePath + "/settings")) {
    String err = fbdo.errorReason();
    if (err.indexOf("not exist") < 0) {  // no settings yet = keep defaults, not an error
      fbFails++;
      lastFbError = err;
      logt("FB", "FAILED reading /settings -> %s", err.c_str());
    }
    return;
  }
  FirebaseJson &json = fbdo.jsonObject();
  FirebaseJsonData r;

  json.get(r, "garageDetectCm");
  if (r.success && r.intValue >= 3 && r.intValue <= 200 && r.intValue != detectCm) {
    logt("SETTING", "garage detect distance %d -> %d cm", detectCm, r.intValue);
    detectCm = r.intValue;
  }
  json.get(r, "garageCloseDelaySec");
  if (r.success && r.intValue >= 1 && r.intValue <= 120 &&
      (unsigned long)r.intValue * 1000 != garageCloseMs) {
    logt("SETTING", "garage close delay %lu -> %d s", garageCloseMs / 1000, r.intValue);
    garageCloseMs = (unsigned long)r.intValue * 1000;
  }
  json.get(r, "clothesLineFollowsRain");
  if (r.success && r.type == "boolean" && r.boolValue != windowFollowsRain) {
    logt("SETTING", "clothes line follows rain: %s", r.boolValue ? "ON" : "OFF");
    windowFollowsRain = r.boolValue;
  }
  json.get(r, "historyIntervalSec");
  if (r.success && r.intValue >= 5 && r.intValue <= 3600 &&
      (unsigned long)r.intValue * 1000 != historyEveryMs) {
    logt("SETTING", "history every %lu -> %d s", historyEveryMs / 1000, r.intValue);
    historyEveryMs = (unsigned long)r.intValue * 1000;
  }
}

// ---- Schedules (set in the app) ----
// The app keeps /smartHome/scheduleIndex/m<UTC minute of day> = "key=1,key=0".
// Once per minute the board reads that minute's entry and runs it.
void runSchedules() {
  if (!cloudReady()) return;
  time_t now = time(nullptr);
  if (now < 1700000000) return;  // NTP not synced yet
  if (!timeSynced) {
    timeSynced = true;
    logt("TIME", "clock synced (UTC %02ld:%02ld)", (long)((now / 3600) % 24), (long)((now / 60) % 60));
  }
  long minute = (long)((now / 60) % 1440);
  if (minute == lastScheduleMinute) return;
  lastScheduleMinute = minute;

  if (!Firebase.RTDB.getString(&fbdo, basePath + "/scheduleIndex/m" + String(minute))) return;  // nothing due
  String due = fbdo.stringData();
  logt("SCHED", "UTC %02ld:%02ld -> %s", minute / 60, minute % 60, due.c_str());
  int start = 0;
  while (start < (int)due.length()) {
    int comma = due.indexOf(',', start);
    if (comma < 0) comma = due.length();
    String item = due.substring(start, comma);
    int eq = item.indexOf('=');
    if (eq > 0) {
      String key = item.substring(0, eq);
      bool value = item.substring(eq + 1) == "1";
      int i = commandIndex(key);
      if (i >= 0) {
        handleCommand(key, value);
        syncCommand(COMMAND_KEYS[i], value);  // apps show the new state
      }
    }
    start = comma + 1;
  }
}

// ---- History (for the app's charts) ----
void pushHistory() {
  if (!cloudReady()) return;
  FirebaseJson h;
  h.set("t/.sv", "timestamp");
  if (lastDistance >= 0) h.set("distanceCm", (int)(lastDistance * 10) / 10.0);
  h.set("raining", raining);
  h.set("fire", fireDetected);
  h.set("garageOpen", garageOpen);
  h.set("clothesLineOpen", windowOpen);
  h.set("rssi", WiFi.RSSI());
  fbResult(Firebase.RTDB.pushJSONAsync(&fbWrite, basePath + "/history", &h), "history");
}

// Runs in the Firebase stream task: NO Firebase calls here, just raise a flag.
void streamCallback(FirebaseStream data) {
  streamEvents++;
  commandsDirty = true;
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) streamTimeouts++;
}

// =====================================================================
// Wi-Fi + Firebase startup
// =====================================================================
void connectWiFi() {
  logt("WIFI", "connecting to \"%s\"...", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(250);
  }
  if (WiFi.status() == WL_CONNECTED) {
    logt("WIFI", "connected, IP %s, signal %d dBm", WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    logt("WIFI", "FAILED (status %d). Check SSID/password and that it's 2.4 GHz.", WiFi.status());
    logt("WIFI", "sensors keep working offline; retrying every %lus", WIFI_RETRY_MS / 1000);
  }
  wasWifiConnected = WiFi.status() == WL_CONNECTED;
}

void startFirebase() {
  logt("FB", "starting Firebase...");
  config.database_url = FIREBASE_HOST;
  if (strlen(DEVICE_PASSWORD) > 0) {
    // Email/password login: works with the locked-down security rules.
    config.api_key = FIREBASE_API_KEY;
    auth.user.email = DEVICE_EMAIL;
    auth.user.password = DEVICE_PASSWORD;
    config.token_status_callback = tokenStatusCallback;  // prints token progress
    logt("FB", "signing in as %s", DEVICE_EMAIL);
  } else {
    config.signer.tokens.legacy_token = FIREBASE_LEGACY_TOKEN;
    logt("FB", "no DEVICE_PASSWORD set: using the open-database token");
  }
  fbdo.setResponseSize(4096);
  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);
  firebaseStarted = true;

  // Wait (max 15 s) for the login token before the first request.
  unsigned long t0 = millis();
  while (!Firebase.ready() && millis() - t0 < 15000) delay(100);
  if (!Firebase.ready()) {
    logt("FB", "! not signed in yet (check DEVICE_EMAIL / DEVICE_PASSWORD); will keep retrying");
  } else {
    logt("FB", "signed in, ready");
  }
  configTime(0, 0, "pool.ntp.org", "time.google.com");  // UTC clock for schedules

  // Seed the whole tree in ONE request so the apps match the hardware.
  FirebaseJson seed;
  seed.set("garage/open", garageOpen);
  seed.set("garage/autoMode", autoMode);
  seed.set("garage/distanceCm", lastDistance > 0 ? lastDistance : 0);
  seed.set("window/open", windowOpen);
  seed.set("window/raining", raining);
  seed.set("fan/on", fanOn);
  for (int i = 0; i < N_LIGHTS; i++) seed.set(String("lights/led") + (i + 1), leds[i]);
  seed.set("fire/detected", fireDetected);
  seed.set("fire/buzzerOn", buzzerOn);
  for (int i = 0; i < N_COMMANDS; i++) {
    bool v = (i == commandIndex("garageOpen")) ? garageOpen
           : (i == commandIndex("windowOpen")) ? windowOpen
           : (i == commandIndex("autoMode")) ? autoMode
           : false;
    lastCmd[i] = v;
    seed.set(String("commands/") + COMMAND_KEYS[i], v);
  }
  seed.set("status/online", true);
  seed.set("status/wifiRssi", WiFi.RSSI());
  seed.set("status/lastSeen/.sv", "timestamp");  // server time (ms), for online/offline
  seed.set("status/uptimeSec", (int)(millis() / 1000));
  fbResult(Firebase.RTDB.updateNode(&fbdo, basePath, &seed), "seed /smartHome", fbdo);

  if (!Firebase.RTDB.beginStream(&stream, basePath + "/commands")) {
    logt("FB", "stream FAILED: %s (commands still read every %lus)",
         stream.errorReason().c_str(), CMD_BACKUP_FETCH_MS / 1000);
  } else {
    Firebase.RTDB.setStreamCallback(&stream, streamCallback, streamTimeoutCallback);
    logt("FB", "listening on %s/commands", basePath.c_str());
  }
  commandsDirty = true;
}

void maintainWiFi() {
  bool connected = WiFi.status() == WL_CONNECTED;
  if (connected && !wasWifiConnected) {
    logt("WIFI", "connected, IP %s, signal %d dBm", WiFi.localIP().toString().c_str(), WiFi.RSSI());
    if (!firebaseStarted) startFirebase();
    commandsDirty = true;
  } else if (!connected && wasWifiConnected) {
    wifiDrops++;
    logt("WIFI", "LOST connection (drop #%lu); sensors keep working, retrying", wifiDrops);
  }
  wasWifiConnected = connected;
  if (!connected && millis() - lastWifiTryMs >= WIFI_RETRY_MS) {
    lastWifiTryMs = millis();
    WiFi.reconnect();
  }
}

// =====================================================================
// Sensors
// =====================================================================
float getDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 25000);  // ~4 m max, never blocks > 25 ms
  if (duration == 0) return -1;
  float cm = duration * 0.0343f / 2.0f;
  if (cm < 2 || cm > 400) return -1;  // outside the HC-SR04's real range = bad echo
  return cm;
}

bool readRain() {
  bool high = digitalRead(RAIN_SENSOR_PIN) == HIGH;
  return RAIN_ACTIVE_LOW ? !high : high;
}

bool readFlame() {
  bool high = digitalRead(FLAME_SENSOR_PIN) == HIGH;
  return FLAME_ACTIVE_LOW ? !high : high;
}

void updateGarage() {
  if (millis() - lastUltrasonicMs < ULTRASONIC_EVERY_MS) return;
  lastUltrasonicMs = millis();
  lastDistance = getDistanceCm();
  if (!autoMode) return;

  bool near = lastDistance > 0 && lastDistance <= detectCm;
  if (near) {
    if (carLeftTime != 0) {
      logt("GARAGE", "car back at %.1f cm, close cancelled", lastDistance);
      carLeftTime = 0;
    }
    if (!garageOpen) {
      char why[48];
      snprintf(why, sizeof(why), "car at %.1f cm", lastDistance);
      setGarage(true, false, why);
    }
  } else if (garageOpen) {
    if (carLeftTime == 0) {
      carLeftTime = millis();
      logt("GARAGE", "car gone (%.1f cm), closing in %lus", lastDistance, garageCloseMs / 1000);
    }
    if (millis() - carLeftTime >= garageCloseMs) {
      setGarage(false, false, "car gone for the close delay");
    }
  }
}

void updateRain() {
  bool now = readRain();
  if (now != rainReading) {
    rainReading = now;
    rainChangedAt = millis();
  }
  if (rainReading != raining && millis() - rainChangedAt >= RAIN_DEBOUNCE_MS) {
    raining = rainReading;
    logt("RAIN", raining ? "RAIN DETECTED" : "rain stopped");
    fbSetBool("/window/raining", raining);
    if (raining && windowOpen) setWindow(false, false, "rain");
    else if (!raining && !windowOpen && windowFollowsRain) setWindow(true, false, "dry again");
  }
}

void updateFire() {
  bool now = readFlame();
  if (now != flameReading) {
    flameReading = now;
    flameChangedAt = millis();
  }
  if (flameReading != fireDetected && millis() - flameChangedAt >= FLAME_CONFIRM_MS) {
    publishFire(flameReading);
  }
}

void publishStatus() {
  if (!cloudReady()) return;
  FirebaseJson st;
  st.set("online", true);
  st.set("wifiRssi", WiFi.RSSI());
  st.set("lastSeen/.sv", "timestamp");  // server time (ms): apps compare with now
  st.set("uptimeSec", (int)(millis() / 1000));
  fbResult(Firebase.RTDB.updateNodeAsync(&fbWrite, basePath + "/status", &st), "status");

  FirebaseJson g;
  g.set("autoMode", autoMode);
  if (lastDistance >= 0) g.set("distanceCm", (int)(lastDistance * 10) / 10.0);
  fbResult(Firebase.RTDB.updateNodeAsync(&fbWrite, basePath + "/garage", &g), "garage status");
}

// =====================================================================
// Debug output
// =====================================================================
void printState() {
  logt("STATE", "garage %s (auto %s) dist %.1f cm | window %s, rain %s | fan %s",
       garageOpen ? "OPEN" : "closed", autoMode ? "ON" : "OFF", lastDistance,
       windowOpen ? "OPEN" : "closed", raining ? "YES" : "no", fanOn ? "ON" : "off");
  logt("STATE", "lights %d%d%d | fire %s, buzzer %s%s", leds[0], leds[1], leds[2],
       fireDetected ? "YES" : "no", buzzerOn ? "ON" : "off", silenceBuzzer ? " (silenced)" : "");
}

void printHealth() {
  Serial.println("------------------------------------------------------------------");
  bool wifi = WiFi.status() == WL_CONNECTED;
  if (wifi)
    logt("HEALTH", "Wi-Fi OK %d dBm %s%s", WiFi.RSSI(), WiFi.localIP().toString().c_str(),
         WiFi.RSSI() < -80 ? "  ! WEAK signal: move the board closer to the router" : "");
  else
    logt("HEALTH", "Wi-Fi DOWN (status %d), drops so far %lu", WiFi.status(), wifiDrops);
  logt("HEALTH", "Firebase %s | stream events %lu, timeouts %lu | command reads %lu",
       !firebaseStarted ? "not started" : (Firebase.ready() ? "ready" : "NOT ready"),
       (unsigned long)streamEvents, (unsigned long)streamTimeouts, cmdFetches);
  logt("HEALTH", "writes ok %lu, failed %lu | last error: %s", fbWritesOk, fbFails, lastFbError.c_str());
  logt("HEALTH", "free heap %u bytes | slowest loop %lu ms (%lu loops over 1 s)",
       ESP.getFreeHeap(), loopMaxMs, loopSlowCount);
  if (ESP.getFreeHeap() < 30000) logt("HEALTH", "  ! low memory");
  printState();
  Serial.println("------------------------------------------------------------------");
  loopMaxMs = 0;
}

void printLive() {
  logt("LIVE", "ultrasonic %.1f cm | rain pin %d -> %s | flame pin %d -> %s",
       lastDistance, digitalRead(RAIN_SENSOR_PIN), readRain() ? "wet" : "dry",
       digitalRead(FLAME_SENSOR_PIN), readFlame() ? "FLAME" : "none");
  logt("LIVE", "window servo %d deg (%s) | buzzer pin %d (%s) | fan relay pin %d",
       windowServo.read(), windowOpen ? "open" : "closed", digitalRead(BUZZER_PIN),
       buzzerOn ? "sounding" : "silent", digitalRead(FAN_RELAY_PIN));
}

// Proves the buzzer and window servo are wired and powered, before Wi-Fi starts.
void selfTest() {
  logt("TEST", "buzzer: one short beep now (silence = check + on GPIO 25, - on GND)");
  digitalWrite(BUZZER_PIN, BUZZER_ACTIVE_LOW ? LOW : HIGH);
  delay(150);
  digitalWrite(BUZZER_PIN, BUZZER_ACTIVE_LOW ? HIGH : LOW);

  logt("TEST", "window servo: OPEN (%d deg)...", WINDOW_OPEN_ANGLE);
  windowServo.write(WINDOW_OPEN_ANGLE);
  delay(700);
  logt("TEST", "window servo: CLOSED (%d deg)", WINDOW_CLOSED_ANGLE);
  windowServo.write(WINDOW_CLOSED_ANGLE);
  delay(700);
  logt("TEST", "no movement? orange -> GPIO 23, servo 5V(-) joined to ESP32 GND");
}

void printHelp() {
  Serial.println();
  Serial.println("Commands: h help | r health | v live readings | f fetch commands");
  Serial.println("          g garage | w window | n fan | 1-3 lights | b beep | a garage auto");
  Serial.println();
}

void handleSerial() {
  while (Serial.available()) {
    char ch = tolower(Serial.read());
    switch (ch) {
      case 'h': printHelp(); break;
      case 'r': printHealth(); break;
      case 'v':
        liveReadings = !liveReadings;
        logt("DEBUG", "live readings %s", liveReadings ? "ON" : "OFF");
        break;
      case 'f': fetchCommands("manual"); break;
      case 'g':
        if (autoMode) {
          autoMode = false;
          syncCommand("autoMode", false);
          fbSetBool("/garage/autoMode", false);
        }
        setGarage(!garageOpen, false, "serial command (auto OFF)");
        break;
      case 'w':
        if (!windowOpen && raining) logt("WINDOW", "refused: raining");
        else setWindow(!windowOpen, false, "serial command");
        break;
      case 'n':
        setFan(!fanOn, "serial command");
        syncCommand("fanOn", fanOn);
        break;
      case '1': case '2': case '3': {
        int i = ch - '1';
        setLight(i, !leds[i], "serial command");
        syncCommand(COMMAND_KEYS[3 + i], leds[i]);
        break;
      }
      case 'b':
        logt("FIRE", "beep test");
        digitalWrite(BUZZER_PIN, BUZZER_ACTIVE_LOW ? LOW : HIGH);
        delay(300);
        digitalWrite(BUZZER_PIN, (buzzerOn != BUZZER_ACTIVE_LOW) ? HIGH : LOW);
        break;
      case 'a':
        autoMode = !autoMode;
        carLeftTime = 0;
        logt("GARAGE", "auto mode %s (serial command)", autoMode ? "ON" : "OFF");
        syncCommand("autoMode", autoMode);
        fbSetBool("/garage/autoMode", autoMode);
        break;
      default: break;  // ignore newlines etc.
    }
  }
}

// =====================================================================
// Setup / loop
// =====================================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("=== Calm Hills Smart Home ESP32 ===");
  Serial.println("Pins: TRIG=5 ECHO=18 GARAGE_SERVO=19 WINDOW_SERVO=23 RAIN=4 FAN_RELAY=13 "
                 "FLAME=34 BUZZER=25 LIGHTS=26,27,32");
  logt("BOOT", "last reset: %s", resetReason());
  if (esp_reset_reason() == ESP_RST_BROWNOUT) {
    logt("BOOT", "! BROWNOUT: power dipped (servos/relay on USB power?). Use the external 5V");
    logt("BOOT", "  for servos + relay, and join its GND to the ESP32 GND.");
  }

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(RAIN_SENSOR_PIN, INPUT_PULLUP);  // bare 2-pin rain plate floats when dry
  pinMode(FLAME_SENSOR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(FAN_RELAY_PIN, OUTPUT);
  for (int i = 0; i < N_LIGHTS; i++) {
    pinMode(LED_PINS[i], OUTPUT);
    digitalWrite(LED_PINS[i], LOW);
  }
  digitalWrite(BUZZER_PIN, BUZZER_ACTIVE_LOW ? HIGH : LOW);        // buzzer silent
  digitalWrite(FAN_RELAY_PIN, FAN_RELAY_ACTIVE_LOW ? HIGH : LOW);  // fan off

  garageServo.setPeriodHertz(50);
  windowServo.setPeriodHertz(50);
  garageServo.attach(GARAGE_SERVO_PIN, 500, 2400);
  windowServo.attach(WINDOW_SERVO_PIN, 500, 2400);
  garageServo.write(CLOSED_ANGLE);
  windowServo.write(WINDOW_CLOSED_ANGLE);

  if (SELF_TEST_AT_BOOT) selfTest();

  raining = rainReading = readRain();
  if (windowFollowsRain && !raining) {
    windowServo.write(WINDOW_OPEN_ANGLE);
    windowOpen = true;
    logt("WINDOW", "OPEN at start (dry, follows rain)");
  }
  fireDetected = false;
  flameReading = readFlame();
  flameChangedAt = millis();
  lastDistance = getDistanceCm();
  logt("BOOT", "sensors: distance %.1f cm, rain %s, flame %s", lastDistance,
       raining ? "WET" : "dry", flameReading ? "SEEN" : "none");

  connectWiFi();
  if (WiFi.status() == WL_CONNECTED) startFirebase();

  printHelp();
  logt("BOOT", "system ready");
  printState();
}

void loop() {
  unsigned long loopStart = millis();
  handleSerial();
  maintainWiFi();

  // Sensors first, every pass
  updateGarage();
  updateRain();
  updateFire();

  // Cloud: commands on stream events (plus a backup read), status every 5 s
  if (cloudReady()) {
    if (commandsDirty || millis() - lastCmdFetchMs >= CMD_BACKUP_FETCH_MS) {
      const char *why = commandsDirty ? "stream event" : "backup poll";
      commandsDirty = false;
      lastCmdFetchMs = millis();
      fetchCommands(why);
    }
    if (millis() - lastStatusMs >= STATUS_INTERVAL_MS) {
      lastStatusMs = millis();
      publishStatus();
    }
    if (lastSettingsMs == 0 || millis() - lastSettingsMs >= SETTINGS_EVERY_MS) {
      lastSettingsMs = millis();
      fetchSettings();
    }
    if (millis() - lastHistoryMs >= historyEveryMs) {
      lastHistoryMs = millis();
      pushHistory();
    }
    runSchedules();
  }

  if (liveReadings && millis() - lastLiveMs >= LIVE_EVERY_MS) {
    lastLiveMs = millis();
    printLive();
  }
  if (millis() - lastHealthMs >= HEALTH_EVERY_MS) {
    lastHealthMs = millis();
    printHealth();
  }

  unsigned long took = millis() - loopStart;
  if (took > loopMaxMs) loopMaxMs = took;
  if (took > 1000) {
    loopSlowCount++;
    logt("DEBUG", "! slow loop: %lu ms (network?)", took);
  }
  delay(10);
}
