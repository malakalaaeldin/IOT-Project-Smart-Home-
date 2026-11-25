
#include <ESP32Servo.h>

// Ultrasonic sensor pins
#define TRIG_PIN 5
#define ECHO_PIN 18

// Servo pin
#define SERVO_PIN 19

Servo garageServo;

// Settings
const int detectionDistance = 15;
const int openAngle = 90;
const int closedAngle = 0;

bool gateOpen = false;
unsigned long carLeftTime = 0;

void setup() {

  Serial.begin(115200);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  garageServo.setPeriodHertz(50);
  garageServo.attach(SERVO_PIN, 500, 2400);

  garageServo.write(closedAngle);

  Serial.println("Automatic Garage System Ready!");
}

float getDistance() {

  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);

  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    return -1;
  }

  float distance = duration * 0.0343 / 2;

  return distance;
}

void loop() {

  float distance = getDistance();

  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" cm");

  // Detect car
  if (distance > 0 && distance <= detectionDistance) {

    carLeftTime = 0;

    if (!gateOpen) {

      garageServo.write(openAngle);
      gateOpen = true;

      Serial.println("CAR DETECTED!");
      Serial.println("GARAGE GATE OPENED!");
    }
  }

  // Car has left the detection area
  else if (gateOpen) {

    if (carLeftTime == 0) {
      carLeftTime = millis();
    }

    // Close gate after 3 seconds without detecting car
    if (millis() - carLeftTime >= 3000) {

      garageServo.write(closedAngle);
      gateOpen = false;
      carLeftTime = 0;

      Serial.println("CAR LEFT!");
      Serial.println("GARAGE GATE CLOSED!");
    }
  }

  delay(100);
}
