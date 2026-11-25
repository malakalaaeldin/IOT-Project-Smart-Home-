/*
 * Garage test with full debugging — Calm Hills Smart Home
 * Ultrasonic (HC-SR04) + garage servo + garage light. No Wi-Fi.
 * Uses the same auto open/close rules as the main firmware.
 *
 * Board: ESP32 Dev Module · Library: ESP32Servo · Serial Monitor @ 115200
 *
 * Wiring:
 *   HC-SR04 VCC -> 5V, GND -> GND, TRIG -> GPIO 5, ECHO -> GPIO 18
 *   Servo red -> external 5V, brown -> GND, orange -> GPIO 19
 *   External 5V (-) MUST also connect to an ESP32 GND pin (shared ground)
 *   Garage light LED -> GPIO 26 -> 220 ohm -> GND (optional)
 *
 * Commands (type in Serial Monitor, then Enter):
 *   h        help                      p        print settings
 *   o        open now (manual)         c        close now (manual)
 *   a        auto mode on/off          s        servo sweep test (0 -> 90 -> 0)
 *   v        verbose: every reading on/off (default: summary every 2 s)
 *   t20      set detect distance to 20 cm
 *   d5000    set close delay to 5000 ms
 */

#include <ESP32Servo.h>
#include "esp_system.h"

// Pins (same as the main firmware)
#define TRIG_PIN 5
#define ECHO_PIN 18
#define SERVO_PIN 19
#define GARAGE_LIGHT_PIN 26

const int OPEN_ANGLE = 90;
const int CLOSED_ANGLE = 0;
int detectCm = 15;                    // same as DETECTION_CM in the main firmware
unsigned long closeDelayMs = 3000;    // same as GARAGE_CLOSE_MS
const unsigned long ECHO_TIMEOUT_US = 30000;  // ~5 m max range
const unsigned long STATS_EVERY_MS = 2000;
const unsigned long STUCK_WARN_MS = 10000;    // open + "near" this long -> warn

Servo garageServo;
bool gateOpen = false;
bool autoMode = true;
bool verbose = false;
unsigned long leftAt = 0;        // when the object went away (0 = present / not counting)
unsigned long nearSince = 0;     // when the current "near" streak started
int lastCountdownShown = -1;

// Stats for the current 2 s window
unsigned long statsStart = 0;
int nReadings = 0, nTimeouts = 0, nTiny = 0;
float sum = 0, sumSq = 0, minCm = 9999, maxCm = 0;

// ---------- helpers ----------
void logt(const char *fmt, ...) {
  char buf[200];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buf, sizeof(buf), fmt, args);
  va_end(args);
  Serial.printf("[%7.2fs] %s\n", millis() / 1000.0, buf);
}

const char *resetReason() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "power-on";
    case ESP_RST_SW: return "software restart";
    case ESP_RST_PANIC: return "crash (panic)";
    case ESP_RST_BROWNOUT: return "BROWNOUT (voltage dropped!)";
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT: return "watchdog";
    case ESP_RST_EXT: return "reset button";
    default: return "other";
  }
}

// One ping: returns echo time in microseconds (0 = no echo)
unsigned long pingUs() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  return pulseIn(ECHO_PIN, HIGH, ECHO_TIMEOUT_US);
}

// Median of 5 pings: ignores single bad echoes. Returns -1 if most pings failed.
float readDistanceCm(unsigned long &rawUsOut) {
  unsigned long us[5];
  int ok = 0;
  for (int i = 0; i < 5; i++) {
    unsigned long d = pingUs();
    if (d > 0) us[ok++] = d;
    delay(8);  // let echoes die down between pings
  }
  if (ok < 3) {
    rawUsOut = 0;
    return -1;
  }
  // sort the valid ones, take the middle
  for (int i = 0; i < ok; i++)
    for (int j = i + 1; j < ok; j++)
      if (us[j] < us[i]) { unsigned long t = us[i]; us[i] = us[j]; us[j] = t; }
  rawUsOut = us[ok / 2];
  return rawUsOut * 0.0343f / 2.0f;
}

void setGate(bool open, const char *why) {
  garageServo.write(open ? OPEN_ANGLE : CLOSED_ANGLE);
  digitalWrite(GARAGE_LIGHT_PIN, open ? HIGH : LOW);
  gateOpen = open;
  leftAt = 0;
  lastCountdownShown = -1;
  logt(">>> GARAGE %s (servo %d deg, light %s)  reason: %s", open ? "OPEN" : "CLOSED",
       open ? OPEN_ANGLE : CLOSED_ANGLE, open ? "on" : "off", why);
}

void printSettings() {
  Serial.println();
  Serial.println("---- settings ----");
  Serial.printf("auto mode     : %s\n", autoMode ? "ON (sensor opens/closes)" : "OFF (only o / c)");
  Serial.printf("detect at     : <= %d cm\n", detectCm);
  Serial.printf("close delay   : %lu ms after the object leaves\n", closeDelayMs);
  Serial.printf("servo angles  : open %d, closed %d\n", OPEN_ANGLE, CLOSED_ANGLE);
  Serial.printf("garage now    : %s\n", gateOpen ? "OPEN" : "closed");
  Serial.printf("verbose       : %s\n", verbose ? "every reading" : "summary every 2 s");
  Serial.println("------------------");
  Serial.println();
}

void printHelp() {
  Serial.println();
  Serial.println("Commands: h help | p settings | o open | c close | a auto on/off");
  Serial.println("          s servo sweep | v verbose | t20 detect cm | d5000 close delay ms");
  Serial.println();
}

void servoSweep() {
  logt("SERVO SWEEP: 0 -> 90 -> 0 deg. Watch the arm move smoothly.");
  logt("  If the ESP32 restarts now -> servo power problem (see reset reason at boot).");
  for (int a = 0; a <= 90; a += 10) { garageServo.write(a); delay(80); }
  delay(400);
  for (int a = 90; a >= 0; a -= 10) { garageServo.write(a); delay(80); }
  garageServo.write(gateOpen ? OPEN_ANGLE : CLOSED_ANGLE);
  logt("SERVO SWEEP done, back to %s.", gateOpen ? "OPEN" : "CLOSED");
}

void handleSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  line.toLowerCase();
  if (line.length() == 0) return;
  char cmd = line[0];
  String arg = line.substring(1);
  arg.trim();

  if (cmd == 'h') printHelp();
  else if (cmd == 'p') printSettings();
  else if (cmd == 'o') { autoMode = false; setGate(true, "manual command 'o' (auto mode now OFF)"); }
  else if (cmd == 'c') { autoMode = false; setGate(false, "manual command 'c' (auto mode now OFF)"); }
  else if (cmd == 'a') {
    autoMode = !autoMode;
    leftAt = 0;
    logt("AUTO MODE %s", autoMode ? "ON: sensor controls the garage" : "OFF: only o / c move it");
  } else if (cmd == 's') servoSweep();
  else if (cmd == 'v') { verbose = !verbose; logt("verbose %s", verbose ? "ON (every reading)" : "OFF (summary)"); }
  else if (cmd == 't' && arg.toInt() > 0) { detectCm = arg.toInt(); logt("detect distance -> %d cm", detectCm); }
  else if (cmd == 'd' && arg.toInt() > 0) { closeDelayMs = arg.toInt(); logt("close delay -> %lu ms", closeDelayMs); }
  else logt("unknown command '%s' (type h for help)", line.c_str());
}

void resetStats() {
  statsStart = millis();
  nReadings = nTimeouts = nTiny = 0;
  sum = sumSq = 0;
  minCm = 9999;
  maxCm = 0;
}

void printStats(float lastCm) {
  int good = nReadings - nTimeouts;
  Serial.println("------------------------------------------------------------");
  if (good > 0) {
    float avg = sum / good;
    float var = sumSq / good - avg * avg;
    float noise = var > 0 ? sqrt(var) : 0;
    logt("DISTANCE  now %.1f cm | min %.1f  max %.1f  avg %.1f | noise +/-%.1f cm",
         lastCm, minCm, maxCm, avg, noise);
    if (noise > 5) logt("  ! noisy readings: aim the sensor at a flat object, check wires are tight");
  } else {
    logt("DISTANCE  no valid echo in the last 2 s");
  }
  logt("READINGS  %d total, %d no-echo (%d%%)", nReadings, nTimeouts,
       nReadings ? nTimeouts * 100 / nReadings : 0);
  if (nReadings && nTimeouts * 100 / nReadings > 50)
    logt("  ! mostly no echo: check ECHO -> GPIO 18, TRIG -> GPIO 5, VCC is 5V, nothing closer than 2 cm");
  if (nTiny > 0)
    logt("  ! %d readings under 2 cm: impossible for HC-SR04 -> loose/shorted ECHO wire", nTiny);

  // Explain the garage state in plain words
  if (!autoMode) {
    logt("GARAGE    %s | auto mode OFF -> only 'o' / 'c' move it (type a to re-enable)",
         gateOpen ? "OPEN" : "closed");
  } else if (!gateOpen) {
    logt("GARAGE    closed | opens when something is <= %d cm", detectCm);
  } else if (leftAt == 0) {
    logt("GARAGE    OPEN | staying open: object still detected (%.1f cm <= %d cm)", lastCm, detectCm);
  } else {
    long left = (long)closeDelayMs - (long)(millis() - leftAt);
    logt("GARAGE    OPEN | object gone, closing in %.1f s", max(0L, left) / 1000.0);
  }
  Serial.println("------------------------------------------------------------");
}

// ---------- main ----------
void setup() {
  Serial.begin(115200);
  delay(500);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(GARAGE_LIGHT_PIN, OUTPUT);
  digitalWrite(GARAGE_LIGHT_PIN, LOW);

  garageServo.setPeriodHertz(50);
  garageServo.attach(SERVO_PIN, 500, 2400);
  garageServo.write(CLOSED_ANGLE);

  Serial.println();
  Serial.println("=== Garage test (debug) ===");
  Serial.println("TRIG=5 ECHO=18 SERVO=19 LIGHT=26");
  logt("last reset reason: %s", resetReason());
  if (esp_reset_reason() == ESP_RST_BROWNOUT) {
    logt("  ! BROWNOUT: the board lost power, usually the servo pulling too much current.");
    logt("    Power the servo from the external 5V AND join its GND to the ESP32 GND.");
  }
  printSettings();
  printHelp();
  logt("Put your hand within %d cm of the sensor to open, then take it away.", detectCm);
  resetStats();
}

void loop() {
  handleSerial();

  unsigned long rawUs = 0;
  float cm = readDistanceCm(rawUs);
  bool echo = cm > 0;
  bool near = echo && cm <= detectCm;

  // stats
  nReadings++;
  if (!echo) nTimeouts++;
  else {
    if (cm < 2) nTiny++;
    sum += cm;
    sumSq += cm * cm;
    if (cm < minCm) minCm = cm;
    if (cm > maxCm) maxCm = cm;
  }

  if (verbose) {
    if (echo)
      logt("echo %5lu us -> %6.1f cm  %s", rawUs, cm, near ? "NEAR" : "far");
    else
      logt("no echo (timeout) -> treated as 'nothing there'");
  }

  // near-streak tracking (for the stuck warning)
  if (near) {
    if (nearSince == 0) nearSince = millis();
  } else {
    nearSince = 0;
  }

  // ---- same auto logic as the main firmware ----
  if (autoMode) {
    if (near) {
      if (leftAt != 0) {
        logt("object back at %.1f cm -> close countdown cancelled", cm);
        leftAt = 0;
        lastCountdownShown = -1;
      }
      if (!gateOpen) {
        char why[60];
        snprintf(why, sizeof(why), "object at %.1f cm (<= %d cm)", cm, detectCm);
        setGate(true, why);
      }
    } else if (gateOpen) {
      if (leftAt == 0) {
        leftAt = millis();
        if (echo)
          logt("object gone (now %.1f cm > %d cm) -> closing in %.1f s", cm, detectCm, closeDelayMs / 1000.0);
        else
          logt("object gone (no echo) -> closing in %.1f s", closeDelayMs / 1000.0);
      }
      unsigned long waited = millis() - leftAt;
      int secsLeft = (int)((closeDelayMs - min(waited, closeDelayMs) + 999) / 1000);
      if (secsLeft != lastCountdownShown && secsLeft > 0) {
        lastCountdownShown = secsLeft;
        logt("  closing in %d...", secsLeft);
      }
      if (waited >= closeDelayMs) {
        setGate(false, "nothing within range for the whole close delay");
      }
    }

    // The classic "opens but never closes" cause
    if (gateOpen && nearSince && millis() - nearSince > STUCK_WARN_MS) {
      logt("  ! open for %lus and the sensor STILL sees something at %.1f cm.",
           (millis() - nearSince) / 1000, cm);
      logt("    Is the opened door / servo arm in front of the sensor? Move the sensor,");
      logt("    or lower the detect distance (e.g. type t8).");
      nearSince = millis();  // repeat the warning every 10 s, not every loop
    }
  }

  if (millis() - statsStart >= STATS_EVERY_MS) {
    if (!verbose) printStats(cm);
    resetStats();
  }

  delay(40);
}
