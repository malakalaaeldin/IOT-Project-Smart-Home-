# Street lights + entrance gate (Arduino module)

A standalone Arduino module at the villa entrance. When a car reaches the gate,
the street lights turn on one after the other, the gate opens, and the LCD
welcomes the visitor.

**Board:** Arduino Uno (uses `Servo.h`, 5 V logic)
**Libraries:** `Servo` (built in), `LiquidCrystal I2C` (Frank de Brabander)

## What it does

1. The LCD shows **"Calm Hills Villa / Gate Closed"**.
2. The IR sensor sees a car (output goes LOW).
3. LCD: **"Car Detected"**. Street light 1 turns on, then street light 2 one second later.
4. The gate servo opens (0° → 90°), and the LCD shows **"Welcome to Calm Hills Villa"**.
5. After 1 s the street lights turn off; the gate stays open for another **5 s** (`gateOpenTime`).
6. The gate closes, the LCD returns to "Gate Closed", and the module waits until the car has left the sensor.

## Wiring

| Part | Arduino pin | Notes |
|------|-------------|-------|
| IR obstacle sensor OUT | **D2** | LOW = car detected; VCC → 5V, GND → GND |
| Street light 1 (LED) | **D4** | through a ~220 Ω resistor to GND |
| Street light 2 (LED) | **D3** | through a ~220 Ω resistor to GND |
| Gate servo signal | **D9** | red → 5V, brown → GND |
| LCD 16×2 I2C SDA / SCL | **A4 / A5** | address `0x27`, VCC → 5V, GND → GND |

## Settings

| Constant | Default | Meaning |
|----------|---------|---------|
| `gateOpenTime` | `5000` ms | Extra time the gate stays open after the lights turn off |
| LCD address | `0x27` | Change to `0x3F` if the screen stays blank |

The first version of this sketch (gate closes right away, no extra open time) is kept in
`firmware/legacy/street_lights_gate_v1/`.
