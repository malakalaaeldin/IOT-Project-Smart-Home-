#ifndef PINS_H
#define PINS_H

// ESP32S 38-pin DevKit — safe GPIO map for Calm Hills Smart Home
// (Reference copy; esp32_smart_home.ino defines the same values.)

// Garage ultrasonic (HC-SR04)
#define TRIG_PIN 5
#define ECHO_PIN 18

// Servos (signal only — power from external 5V)
#define GARAGE_SERVO_PIN 19
#define WINDOW_SERVO_PIN 23   // window/roof, closes on rain (was front door)

// Rain sensor module digital output (DO LOW = wet on FC-37 / YL-83)
#define RAIN_SENSOR_PIN 4

// Fan relay module IN (most boards: LOW = relay on)
#define FAN_RELAY_PIN 13

// Flame sensor digital output
#define FLAME_SENSOR_PIN 34

// Buzzer
#define BUZZER_PIN 25

// Lights
#define LED1_PIN 26  // general control light 1
#define LED2_PIN 27  // general control light 2
#define LED3_PIN 32  // general control light 3

#endif
