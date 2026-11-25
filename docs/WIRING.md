# Calm Hills Smart Home — Wiring (ESP32S 38-pin)

Pin map and wiring for the current hardware: the garage (servo + ultrasonic), the **window/roof servo + rain sensor**, the **fan on a relay**, 3 general control lights (LEDs), and the flame sensor + buzzer. The front door servo and IR sensor are gone. Their pins now drive the window servo (GPIO 23) and read the rain sensor (GPIO 4).

## Power (important)

| Rail | Use |
|------|-----|
| USB 5V (from PC) | ESP32 only, while flashing / debugging |
| External **5V ≥ 2A** adapter | Both servos (garage + window) and the relay module's VCC |
| Fan supply | Whatever voltage your fan needs (e.g. 5V or 12V), switched **through the relay contacts**. It never goes into an ESP32 pin |
| ESP32 **3V3** pin | Rain sensor module VCC, flame sensor VCC |
| Common **GND** | Tie the adapter GND, the ESP32 GND and every module GND together |

**Do not** power the servos from a raw 9V battery. Use regulated 5V with enough current. A 9V pack is OK only if stepped down to 5V with a buck converter rated ≥2A.

## Pin map (matches `firmware/esp32_smart_home/pins.h`)

| Device | ESP32 GPIO | Notes |
|--------|------------|-------|
| Ultrasonic TRIG | **5** | HC-SR04 |
| Ultrasonic ECHO | **18** | 3.3V-tolerant on most clones |
| Garage servo signal | **19** | External 5V power |
| Window/roof servo signal | **23** | External 5V power. Closes automatically when it rains |
| Rain sensor DO | **4** | FC-37 / YL-83 module. DO goes LOW when wet |
| Fan relay IN | **13** | Relay module. Default: LOW = fan on |
| Flame sensor DO | **34** | Input-only pin. HIGH = flame on our module |
| Buzzer | **25** | Active HIGH |
| Light 1 (general control) | **26** | ~220Ω resistor in series |
| Light 2 (general control) | **27** | ~220Ω |
| Light 3 (general control) | **32** | ~220Ω |
| Common ground | **GND** | Shared with the 5V supply |

Avoid GPIO **6–11** (flash). Leave boot straps (0, 2, 12, 15) alone.

## Wiring each device

### Servos (garage on 19, window on 23)

| Servo wire | Connect to |
|------------|------------|
| Red | External 5V |
| Brown / Black | Common GND |
| Orange / Yellow (signal) | GPIO **19** (garage) or GPIO **23** (window) |

The garage servo turns to 0° for closed and 90° for open (`CLOSED_ANGLE` / `OPEN_ANGLE`). The window servo is the other way round: 90° closed and 0° open (`WINDOW_CLOSED_ANGLE` / `WINDOW_OPEN_ANGLE`).

### Rain sensor

**Bare 2-pin plate (no comparator board):** connect one plate pin to GPIO **4** and the other to **GND**. You don't need 3V3. The firmware turns on GPIO 4's internal pull-up, so a dry plate reads HIGH (dry) and water pulls it LOW (wet). Without the pull-up, the pin floats when dry and reads "wet" at random. Test it with `firmware/tests/rain_test/rain_test.ino`.

**With the comparator board (FC-37 / YL-83, 4 pins):** the kit has two parts, the rain plate and a small board with a blue trimmer pot.

| Comparator board pin | Connect to |
|----------------------|------------|
| VCC | ESP32 **3V3** (keeps DO at a safe 3.3V level) |
| GND | Common GND |
| DO | GPIO **4** |
| AO | Not used |

- Wire the plate's two pins to the board's two-pin header. Either way round is fine.
- Turn the blue pot until the board's DO LED turns **on when you drip water on the plate** and off when it's dry.
- **What happens:** when the plate stays wet for 1.5 s, the firmware closes the window (if it's open) and refuses to open it again until the plate is dry.
- If your module is the other way round (DO goes HIGH when wet), set `RAIN_ACTIVE_LOW = false` in the `.ino`.

### Fan through a relay module (GPIO 13)

```
            ESP32                      Relay module                 Fan circuit
         ┌─────────┐               ┌──────────────┐
  GPIO13 ┤         ├──────────────►│ IN           │
     GND ┤         ├──────────────►│ GND          │
         └─────────┘   5V adapter ►│ VCC          │
                                   │          COM ├──── Fan supply (+)
                                   │          NO  ├──── Fan (+)
                                   │          NC  │     (not used)
                                   └──────────────┘
                                                        Fan (−) ──── Fan supply (−)
```

| Relay pin | Connect to |
|-----------|------------|
| VCC | External **5V** (most relay coils need 5V) |
| GND | Common GND |
| IN | GPIO **13** |
| COM | Fan supply **+** |
| NO (normally open) | Fan **+** |
| NC | Leave empty, so the fan is off when the board is unpowered |

- The fan's **−** goes straight to the fan supply's **−**.
- Most relay boards switch **on** when IN is pulled **LOW**. The firmware assumes that (`FAN_RELAY_ACTIVE_LOW = true`). If the fan runs when it should be off, set it to `false`.
- If your relay board has a **JD-VCC jumper**, leave it fitted unless you know you want opto-isolation.
- **Mains fan (230V):** only with a relay rated for it, in a closed enclosure, wired by someone qualified. For the model house, use a 5V or 12V DC fan.
- The fan is controlled **from the mobile app only** (the switch or a voice command). The web dashboard doesn't show it.

### Ultrasonic HC-SR04 (garage)

| HC-SR04 pin | Connect to |
|-------------|------------|
| VCC | External 5V |
| GND | Common GND |
| TRIG | GPIO **5** |
| ECHO | GPIO **18** (for safety, add a 1k/2k divider to bring ECHO's 5V down to ~3.3V) |

Auto mode opens the garage when something is **≤ 15 cm** away and closes it 3 s after it leaves.

### Flame sensor, buzzer, LEDs

| Part | Wiring |
|------|--------|
| Flame sensor | VCC → 3V3, GND → GND, DO → GPIO **34**. Our module gives DO **HIGH on flame** (`FLAME_ACTIVE_LOW = false`); check yours with `firmware/tests/flame_test` |
| Buzzer (2-pin) | + → GPIO **25**, − → GND. **Not** + → 3V3/5V: on a power pin it beeps nonstop and the code can't silence it |
| Lights 1–3 | GPIO **26 / 27 / 32** → 220Ω → LED long leg; short leg → GND |

## Suggested bring-up order

1. USB only → flash firmware → Serial Monitor @ **115200** → confirm Wi-Fi + "Listening on /smartHome/commands". The apps should show **ESP32 online** within 5 s.
2. Ultrasonic → watch the garage distance in the app or web.
3. Garage servo on external 5V → test auto-open at ≤ 15 cm, then turn auto off and use the app's **Open garage** switch.
4. **Window servo + rain sensor** → open the window from the app, drip water on the plate → the serial log shows `RAIN DETECTED` and `WINDOW CLOSED`, and the app shows "Raining". Try opening it while the plate is wet. It must stay closed.
5. **Fan relay** → you hear the relay click when you flip **Fan on** in the mobile app (serial shows `FAN ON`). Connect the fan only after the click works.
6. LEDs one by one.
7. Flame sensor + buzzer → check the alarm banner and the **Silence** button.

Every 5 s the serial log prints a status line: `Distance | Garage | Window | Rain | Fan | Fire`.

## Libraries (Arduino IDE / Board Manager)

- Board: **ESP32 Dev Module** (ESP32S 38-pin)
- Libraries: `ESP32Servo`, `Firebase ESP Client` (Mobizt)

## Config

Everything is in the one sketch, `firmware/esp32_smart_home/esp32_smart_home.ino`. Wi-Fi and Firebase settings are in the **EDIT THESE** block at the top (`WIFI_SSID`, `WIFI_PASSWORD`, `FIREBASE_HOST`, `FIREBASE_AUTH`). The ESP32 can only join **2.4 GHz** Wi-Fi. Hardware options sit just below the pin list:

| Setting | Default | Change it when |
|---------|---------|----------------|
| `RAIN_ACTIVE_LOW` | `true` | Your rain module's DO goes HIGH when wet |
| `FAN_RELAY_ACTIVE_LOW` | `true` | Your relay switches on when IN is HIGH |
| `OPEN_ANGLE` / `CLOSED_ANGLE` | 90 / 0 | The garage servo needs a different swing |
| `WINDOW_OPEN_ANGLE` / `WINDOW_CLOSED_ANGLE` | 0 / 90 | The window servo turns the wrong way (swap the two) |
| `DETECTION_CM` | 15 | The garage should trigger closer or farther |
