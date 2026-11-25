#include <Servo.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// LCD ADDRESS
LiquidCrystal_I2C lcd(0x27, 16, 2);

// IR Sensor
const int irSensor = 2;

// LEDs
const int led2 = 4;
const int led3 = 3;

// Servo
const int servoPin = 9;
Servo myServo;

// Extra time the gate stays open after the LEDs turn off (milliseconds)
const unsigned long gateOpenTime = 5000;   // 5 seconds

void setup() {

  Serial.begin(9600);

  pinMode(irSensor, INPUT);

  pinMode(led2, OUTPUT);
  pinMode(led3, OUTPUT);

  myServo.attach(servoPin);
  myServo.write(0);

  // Initialize LCD
  lcd.init();
  lcd.backlight();

  lcd.setCursor(0, 0);
  lcd.print("Calm Hills Villa");

  lcd.setCursor(0, 1);
  lcd.print("Gate Closed");
}

void loop() {

  if (digitalRead(irSensor) == LOW) {

    Serial.println("Car detected!");

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Car Detected");

    // First LED
    digitalWrite(led2, HIGH);
    delay(1000);

    // Second LED
    digitalWrite(led3, HIGH);
    delay(1000);

    // Open gate
    myServo.write(90);

    // Welcome message
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Welcome to Calm");

    lcd.setCursor(0, 1);
    lcd.print("Hills Villa");

    delay(1000);   // same timing as before

    // Turn off LEDs (same time as original)
    digitalWrite(led2, LOW);
    digitalWrite(led3, LOW);

    // Keep gate open longer
    delay(gateOpenTime);

    // Close gate
    myServo.write(0);

    // Display closed status
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Calm Hills Villa");

    lcd.setCursor(0, 1);
    lcd.print("Gate Closed");

    // Wait until car leaves
    while (digitalRead(irSensor) == LOW) {
      delay(2000);
    }

    Serial.println("System ready!");
  }
}