/*
 * Rain sensor + window servo test — Calm Hills Smart Home
 * Checks that the rain module (FC-37 / YL-83) is sensing AND that the window
 * servo moves, before you use the full firmware. No Wi-Fi.
 *
 * Library: ESP32Servo (Arduino Library Manager)
 *
 * Wiring (same as the main firmware):
 *   Bare 2-pin rain plate (no comparator board):
 *     one plate pin -> GPIO 4, other plate pin -> GND   (no 3V3 needed)
 *   OR a 4-pin module with comparator board:
 *     VCC -> 3V3, GND -> GND, DO -> GPIO 4, AO -> GPIO 35 (optional)
 *   Servo red       -> external 5V (NOT the ESP32 3V3 pin)
 *   Servo brown     -> GND (shared with the ESP32 GND)
 *   Servo orange    -> GPIO 23
 *
 * How to test:
 *   1. Upload, open Serial Monitor at 115200 (line ending: any).
 *   2. Dry plate  -> "DRY", the servo goes to OPEN (0°).
 *   3. Wet the plate -> "WET", the servo goes to CLOSED (90°), the blue onboard LED turns on.
 *   4. Wipe it dry -> back to "DRY" and OPEN.
 *   Type in the Serial Monitor to move the servo by hand:
 *     o = open, c = close, a = back to automatic (follows the rain sensor)
 *   If the rain state never changes, turn the blue pot on the module slowly
 *   until its DO LED flips when you wet the plate.
 *
 * Note: this test reopens the window when it's dry, so you can watch both
 * directions. The main firmware only closes it on rain; you reopen it from the app.
 */

#include <ESP32Servo.h>

const int RAIN_DO_PIN = 4;          // digital output of the rain module
const int RAIN_AO_PIN = 35;         // analog output (ADC1, input-only); optional
const int WINDOW_SERVO_PIN = 23;    // window/roof servo signal
const bool USE_ANALOG = false;      // true only if a module's AO is wired to GPIO 35
const bool RAIN_ACTIVE_LOW = true;  // most modules: DO LOW = wet
const int ONBOARD_LED = 2;          // blue LED on most ESP32 DevKits

const int OPEN_ANGLE = 0;           // swapped for this window (same as WINDOW_OPEN_ANGLE in main firmware)
const int CLOSED_ANGLE = 90;
const unsigned long DEBOUNCE_MS = 1500;  // plate must stay wet/dry this long (same as firmware)

Servo windowServo;

bool lastWet = false;        // raw reading
bool stableWet = false;      // debounced state that drives the servo
unsigned long changedAt = 0;
unsigned long changes = 0;
unsigned long lastPrint = 0;
bool manual = false;         // true after typing o / c
int servoAngle = -1;

bool readWet() {
  bool high = digitalRead(RAIN_DO_PIN) == HIGH;
  return RAIN_ACTIVE_LOW ? !high : high;
}

void moveServo(int angle, const char *why) {
  if (angle == servoAngle) return;
  servoAngle = angle;
  windowServo.write(angle);
  Serial.printf(">>> SERVO -> %s (%d deg)  [%s]\n", angle == OPEN_ANGLE ? "OPEN" : "CLOSED", angle, why);
}

void setup() {
  Serial.begin(115200);
  delay(500);
  // INPUT_PULLUP is essential for a bare 2-pin rain plate: a dry plate connects
  // nothing, so without the pull-up the pin floats and reads random LOWs ("wet").
  // The pull-up holds it HIGH when dry; water shorts it to GND (LOW) when wet.
  // It is harmless with a 4-pin comparator module too.
  pinMode(RAIN_DO_PIN, INPUT_PULLUP);
  pinMode(ONBOARD_LED, OUTPUT);
  if (USE_ANALOG) {
    analogReadResolution(12);  // 0..4095
  }

  windowServo.setPeriodHertz(50);
  windowServo.attach(WINDOW_SERVO_PIN, 500, 2400);

  Serial.println();
  Serial.println("=== Rain sensor + window servo test ===");
  Serial.println("Rain DO on GPIO 4, AO on GPIO 35 (optional), servo on GPIO 23");
  Serial.println("Wet the plate -> CLOSED; dry -> OPEN. Type o / c / a to test the servo by hand.");
  Serial.println();

  lastWet = stableWet = readWet();
  Serial.printf("Start state: %s\n", stableWet ? "WET" : "DRY");
  moveServo(stableWet ? CLOSED_ANGLE : OPEN_ANGLE, "start");
}

void handleSerial() {
  while (Serial.available()) {
    char ch = tolower(Serial.read());
    if (ch == 'o') {
      manual = true;
      moveServo(OPEN_ANGLE, "manual");
    } else if (ch == 'c') {
      manual = true;
      moveServo(CLOSED_ANGLE, "manual");
    } else if (ch == 'a') {
      manual = false;
      servoAngle = -1;  // force a move to the sensor's position
      Serial.println(">>> AUTO: servo follows the rain sensor again");
      moveServo(stableWet ? CLOSED_ANGLE : OPEN_ANGLE, "auto");
    }
  }
}

void loop() {
  handleSerial();

  bool wet = readWet();
  digitalWrite(ONBOARD_LED, wet ? HIGH : LOW);

  // Raw change: report immediately, start the debounce timer
  if (wet != lastWet) {
    lastWet = wet;
    changedAt = millis();
    Serial.printf("    raw reading now %s (waiting %lu ms to confirm)\n", wet ? "WET" : "DRY", DEBOUNCE_MS);
  }

  // Confirmed change after the debounce time
  if (lastWet != stableWet && millis() - changedAt >= DEBOUNCE_MS) {
    stableWet = lastWet;
    changes++;
    Serial.printf(">>> CHANGED to %s  (change #%lu)\n", stableWet ? "WET (rain detected)" : "DRY", changes);
    if (!manual) {
      moveServo(stableWet ? CLOSED_ANGLE : OPEN_ANGLE, stableWet ? "rain" : "dry");
    }
  }

  // Live reading 3x per second
  if (millis() - lastPrint >= 333) {
    lastPrint = millis();
    int rawDo = digitalRead(RAIN_DO_PIN);
    const char *servo = servoAngle == OPEN_ANGLE ? "OPEN  " : "CLOSED";
    if (USE_ANALOG) {
      // Analog: ~4095 = bone dry, lower = wetter
      int ao = analogRead(RAIN_AO_PIN);
      int wetness = constrain(map(ao, 4095, 0, 0, 100), 0, 100);
      Serial.printf("DO=%d -> %s | AO=%4d | wetness ~%3d%% | servo %s%s [", rawDo, wet ? "WET" : "DRY", ao,
                    wetness, servo, manual ? " (manual)" : "");
      int bars = wetness / 5;
      for (int i = 0; i < 20; i++) Serial.print(i < bars ? '#' : ' ');
      Serial.println("]");
    } else {
      Serial.printf("DO=%d -> %s | servo %s%s\n", rawDo, wet ? "WET" : "DRY", servo, manual ? " (manual)" : "");
    }
  }

  delay(20);
}
