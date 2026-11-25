/*
 * Flame sensor + buzzer test — Calm Hills Smart Home
 * Finds out WHY the buzzer sounds with no fire: sensitivity, wiring, or the
 * buzzer/sensor being the opposite polarity to what the code expects.
 * No Wi-Fi, no libraries.
 *
 * Wiring (same as the main firmware):
 *   Flame module VCC -> 3V3      GND -> GND      DO -> GPIO 34
 *   Flame module AO  -> GPIO 39  (OPTIONAL, 4-pin modules only)
 *   2-pin buzzer: + (long leg) -> GPIO 25, - -> GND.
 *     NOT + -> 3V3/5V: a 2-pin active buzzer on a power pin beeps nonstop,
 *     whatever the code does. GPIO 25 must be its "power" so the code can switch it.
 *   (3-pin buzzer module instead: VCC -> 3V3, GND -> GND, I/O -> GPIO 25)
 *
 * Open Serial Monitor at 115200. Type a letter + Enter:
 *   b = beep test (3 short beeps)        m = mute / unmute the alarm
 *   z = flip buzzer polarity (if it screams when it should be silent)
 *   f = flip flame polarity  (if it says FLAME while the module's own LED is off)
 *   s = print current settings to copy into the main firmware
 *
 * STEP 1 — buzzer: at start it stays SILENT for 2 s, then beeps 3 times.
 *   - Silent, then 3 beeps                       -> buzzer polarity is right.
 *   - Loud the WHOLE time, even during "silent"  -> WIRING: buzzer + is on a
 *     power pin. Move it to GPIO 25 (code can't silence a buzzer on 3V3/5V).
 *   - Loud during "silent", quiet during beeps   -> active-LOW buzzer module: type z
 *     (not possible with a plain 2-pin buzzer).
 * STEP 2 — flame: look at the small LED on the flame module itself.
 *   - Module LED ON with no fire   -> SENSITIVITY: turn the blue pot
 *     counter-clockwise until the LED goes off; keep the sensor away from
 *     sunlight / bright bulbs / IR remotes (they look like fire to it).
 *   - Module LED OFF but this sketch says FLAME -> CODE polarity: type f.
 *   - Reading flickers FLAME/clear many times a second -> loose wire or DO not
 *     connected (GPIO 34 has no internal pull-up, so an unplugged pin floats).
 *   Then hold a lighter ~20-30 cm in front: it must say FLAME and beep.
 */

const int FLAME_DO_PIN = 34;   // input-only pin, NO internal pull-up
const int FLAME_AO_PIN = 39;   // optional analog (ADC1, input-only)
const int BUZZER_PIN = 25;
const bool USE_ANALOG = false; // true only if AO is wired to GPIO 39
const bool BUZZER_ENABLED = false;  // buzzer OFF while testing the flame sensor alone

// Start values = what the main firmware assumes. Flip live with f / z.
bool flameActiveLow = false;   // YOUR module: DO HIGH = flame (tested: DO=0 with no fire)
bool buzzerActiveLow = false;  // plain active buzzer: HIGH = sound

const unsigned long CONFIRM_MS = 300;  // flame must be seen this long

bool muted = false;
bool rawFlame = false;
bool confirmedFlame = false;
unsigned long rawChangedAt = 0;
unsigned long lastPrint = 0;
unsigned long windowStart = 0;
int flipsThisSecond = 0;
int lastFlips = 0;

void buzzer(bool on) {
  if (!BUZZER_ENABLED) on = false;  // buzzer disabled: always silent
  bool level = buzzerActiveLow ? !on : on;
  digitalWrite(BUZZER_PIN, level ? HIGH : LOW);
}

bool readFlame() {
  bool high = digitalRead(FLAME_DO_PIN) == HIGH;
  return flameActiveLow ? !high : high;
}

void beepTest() {
  Serial.println(">>> BEEP TEST: you should hear 3 short beeps now");
  for (int i = 0; i < 3; i++) {
    buzzer(true);
    delay(200);
    buzzer(false);
    delay(250);
  }
  Serial.println(">>> beep test done (buzzer should now be silent)");
}

void printSettings() {
  Serial.println();
  Serial.println("---- copy into esp32_smart_home.ino ----");
  Serial.printf("const bool FLAME_ACTIVE_LOW = %s;\n", flameActiveLow ? "true" : "false");
  Serial.printf("const bool BUZZER_ACTIVE_LOW = %s;\n", buzzerActiveLow ? "true" : "false");
  Serial.println("----------------------------------------");
  Serial.println();
}

void handleSerial() {
  while (Serial.available()) {
    char ch = tolower(Serial.read());
    if (ch == 'b') {
      beepTest();
    } else if (ch == 'm') {
      muted = !muted;
      Serial.printf(">>> alarm %s\n", muted ? "MUTED" : "unmuted");
    } else if (ch == 'z') {
      buzzerActiveLow = !buzzerActiveLow;
      Serial.printf(">>> buzzer polarity flipped: BUZZER_ACTIVE_LOW = %s\n", buzzerActiveLow ? "true" : "false");
      buzzer(false);
    } else if (ch == 'f') {
      flameActiveLow = !flameActiveLow;
      Serial.printf(">>> flame polarity flipped: FLAME_ACTIVE_LOW = %s\n", flameActiveLow ? "true" : "false");
    } else if (ch == 's') {
      printSettings();
    }
  }
}

void setup() {
  pinMode(BUZZER_PIN, OUTPUT);
  buzzer(false);  // silent first thing
  pinMode(FLAME_DO_PIN, INPUT);
  Serial.begin(115200);
  delay(300);
  if (USE_ANALOG) analogReadResolution(12);

  Serial.println();
  Serial.println("=== Flame sensor + buzzer test ===");
  Serial.println("Flame DO on GPIO 34, buzzer on GPIO 25. Commands: b m z f s");
  Serial.println();
  if (BUZZER_ENABLED) {
    Serial.println("STEP 1: buzzer should be SILENT for 2 seconds...");
    delay(2000);
    beepTest();
    Serial.println();
  } else {
    Serial.println("(buzzer disabled: BUZZER_ENABLED = false)");
  }
  Serial.println("STEP 2: watching the flame sensor (no fire nearby please)");

  rawFlame = confirmedFlame = readFlame();
  windowStart = millis();
}

void loop() {
  handleSerial();

  bool now = readFlame();
  if (now != rawFlame) {
    rawFlame = now;
    rawChangedAt = millis();
    flipsThisSecond++;
  }
  if (rawFlame != confirmedFlame && millis() - rawChangedAt >= CONFIRM_MS) {
    confirmedFlame = rawFlame;
    Serial.println(confirmedFlame ? ">>> FLAME DETECTED" : ">>> flame cleared");
  }

  buzzer(confirmedFlame && !muted);

  if (millis() - windowStart >= 1000) {
    lastFlips = flipsThisSecond;
    flipsThisSecond = 0;
    windowStart = millis();
  }

  if (millis() - lastPrint >= 400) {
    lastPrint = millis();
    int rawDo = digitalRead(FLAME_DO_PIN);
    Serial.printf("DO=%d -> %-6s", rawDo, confirmedFlame ? "FLAME" : "clear");
    if (BUZZER_ENABLED) {
      Serial.printf(" | buzzer %-6s%s", (confirmedFlame && !muted) ? "ON" : "off", muted ? " (muted)" : "");
    }
    if (USE_ANALOG) {
      // Most modules: lower AO = stronger IR (closer to flame)
      Serial.printf(" | AO=%4d", analogRead(FLAME_AO_PIN));
    }
    if (lastFlips > 4) {
      Serial.printf(" | UNSTABLE: %d flips/s -> check DO wire, or sensor too sensitive", lastFlips);
    }
    Serial.println();
  }

  delay(10);
}
