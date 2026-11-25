# Firmware

Each folder is one Arduino sketch (open the `.ino` in the Arduino IDE).

| Folder | Board | What it is |
|--------|-------|------------|
| `esp32_smart_home/` | ESP32 Dev Module | **Main system:** garage (ultrasonic + servo), clothes line (rain sensor + servo), fan relay, 3 general control lights, fire alarm (flame + buzzer). Connects to Firebase; controlled by the mobile app |
| `street_lights_gate/` | Arduino Uno | **Street lights + entrance gate:** IR sensor, 2 street lights, servo gate, I2C LCD. Standalone |
| `tests/rain_test/` | ESP32 | Rain sensor + clothes-line servo test |
| `tests/flame_test/` | ESP32 | Flame sensor + buzzer test (finds the sensor/buzzer polarity) |
| `tests/garage_test/` | ESP32 | Ultrasonic + garage servo test with debugging |
| `legacy/` | — | Earlier versions, kept for reference |

Wiring for the ESP32 system: [`docs/WIRING.md`](../docs/WIRING.md).
Wiring for the street lights module: [`street_lights_gate/README.md`](street_lights_gate/README.md).

## Passwords in `esp32_smart_home.ino`

Put your Wi-Fi name/password and the ESP32 device password in the **EDIT THESE** block at the
top of the sketch. A git filter replaces them with placeholders whenever the file is committed,
so the real values stay on your computer only. Set it up once per clone:

```bash
git config filter.stripsecrets.clean "sed -e 's/^#define WIFI_SSID \".*\"/#define WIFI_SSID \"YOUR_WIFI_NAME\"/' -e 's/^#define WIFI_PASSWORD \".*\"/#define WIFI_PASSWORD \"YOUR_WIFI_PASSWORD\"/' -e 's/^#define DEVICE_PASSWORD \".*\"/#define DEVICE_PASSWORD \"\"/'"
git config filter.stripsecrets.smudge cat
```
