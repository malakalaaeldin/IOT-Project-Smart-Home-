# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(The repository also ships a native Android companion in Flutter at `mobile/smart_home_app/`; this record's design work targets the web dashboard in `web/`.)

## Users

Two audiences, confirmed:
- **Demo audience now:** instructors and classmates watching the IoT project presented on a laptop or projector, with the ESP32 model house wired up beside it.
- **Household later:** family members who open the dashboard on phones or laptops to run a real home day to day.

The dashboard should demo well and still feel like a real product that a household could live with.

## Product Purpose

Calm Hills Smart Home lets people see and control one house: garage door, front door, four lights, garage auto mode, and the fire alarm. It works by button, by sensor, and by voice. An ESP32 is the hardware hub; Firebase Realtime Database relays state (`/smartHome/status|garage|frontDoor|lights|fire`) and commands (`/smartHome/commands`). Success means every control reflects the real house within a second and a spoken "open the garage door" just works.

## Positioning

Three control paths reach one house in real time: physical sensors (the ultrasonic garage auto-open and the flame sensor), touch toggles, and a voice agent that combines an instant offline command parser with an LLM (NVIDIA NIM) for free-form requests. The house state is live from real hardware, not simulated.

## Operating Context

- Firebase Hosting serves the dashboard at calm-hills-smart-home.web.app; users sign in with Firebase email/password.
- The ESP32 may be offline during development; the UI must make online or offline status obvious.
- During demos, voice commands are spoken aloud in a room, often in Chrome on a laptop.
- The ESP32 firmware applies a garage command only when `autoMode` is false; manual garage control turns auto mode off.

## Capabilities and Constraints

- Devices: garage (servo, ultrasonic distance in cm, auto mode), front door (servo + IR), lights led1 Living, led2 Outdoor, led3 Hall, led4 Porch, fire (flame detected, buzzer on, silence command).
- Voice: Web Speech API in the browser (Chrome/Edge), with tap-to-talk and hands-free "Hey Home" modes. The browser cannot call the NVIDIA API directly because CORS blocks it, so web AI requests go through an optional local proxy; without it, the offline parser handles commands.
- Static HTML/CSS/JS ES modules with no build step; Firebase JS SDK from gstatic.
- The NVIDIA API key must never ship in deployed web files.

## Brand Commitments

- Name: "Calm Hills Villa" / "Calm Hills Smart Home".
- Voice wake word: "Hey Home".

## Evidence on Hand

- No logo, photography, or brand assets exist. A demo account exists (see README).
- Do not invent energy savings, security claims, or user counts.

## Product Principles

1. The real house is the truth: show live state, never optimistic guesses, and make it plain when the device is offline.
2. Every action is reachable three ways (touch, voice, sensor), and each reflects the others instantly.
3. Safety first: fire alerts outrank everything else on screen.
4. Speak plainly: replies and labels use room names people say ("porch light"), not pin names.
