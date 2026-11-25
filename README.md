# Calm Hills Smart Home

ESP32S + Firebase Realtime Database + Flutter Android app + web dashboard.

**Firebase project:** `calm-hills-smart-home`  
**Web dashboard:** https://calm-hills-smart-home.web.app  
**Console:** https://console.firebase.google.com/project/calm-hills-smart-home/overview

## Repository layout

```
firmware/
  esp32_smart_home/      main ESP32 firmware: garage, clothes line (rain), fan, 3 lights, fire alarm
  street_lights_gate/    Arduino Uno module: IR sensor, street lights, servo gate, LCD
  tests/                 one-part test sketches (rain, flame, garage)
  legacy/                earlier versions, for reference
mobile/smart_home_app/   Flutter app (screens / models / widgets / services)
web/                     web dashboard (Firebase Hosting)
functions/               Cloud Function: push notifications for fire/rain (FCM)
tools/voice-proxy.mjs    local AI proxy for the web dashboard's assistant
docs/                    WIRING.md, requirements PDF, screenshots, design notes
database.rules.json      Realtime Database security rules
firebase.json            Firebase deploy config (hosting, database, functions)
```

See [`firmware/README.md`](firmware/README.md) for every sketch and [`docs/WIRING.md`](docs/WIRING.md) for the ESP32 pin map.

## Demo account

Email/Password Auth is enabled. A demo user was created for testing:

- Email: `demo@calmhills.local`
- Password: `CalmHills123!`

You can also create your own account from the web or Flutter login screens.

## ESP32 firmware

1. Edit the **EDIT THESE** block at the top of `firmware/esp32_smart_home/esp32_smart_home.ino`: set `WIFI_SSID` / `WIFI_PASSWORD` (2.4 GHz Wi-Fi only)
2. Arduino libraries: **ESP32Servo**, **Firebase ESP Client** (Mobizt)
3. Board: **ESP32 Dev Module** · Serial **115200**
4. Pins are in `pins.h` / `docs/WIRING.md`
5. Before committing, set up the password filter once (see `firmware/README.md`) so your Wi-Fi password never reaches GitHub

## Flutter (Android emulator)

Install Flutter if needed, then:

```powershell
cd mobile\smart_home_app
.\tool\bootstrap.ps1
flutter run --dart-define-from-file=secrets.json
```

`minSdk` is 24 (required by `flutter_tts`). The app asks for microphone permission the first time you tap the mic.

Or manually:

```powershell
flutter create . --project-name smart_home_app --org com.calmhills --platforms=android
flutter pub get
flutter run
```

Package id: `com.calmhills.smarthome` (`google-services.json` already present).

## Web

Already deployed. Local files under `web/` — configs in `web/firebase-config.js`.

Redeploy:

```bash
npx -y firebase-tools@latest deploy --only hosting,database --project calm-hills-smart-home
```

## Mobile app (Flutter) — features vs. project requirements

| Requirement | Where |
|---|---|
| Login / logout (Firebase Auth) | `lib/screens/login_screen.dart`, sign-out in the app bar and Settings |
| Live dashboard (StreamBuilder, no refresh button) | `lib/screens/dashboard_screen.dart` |
| Control screen (commands → ESP32 reacts in seconds) | `lib/screens/controls_screen.dart` |
| Device status online/offline per module (`status/lastSeen` server timestamp) | status chip on every module card |
| Alerts (fire, rain, ESP32 offline) | Dashboard alerts + notifications |
| Automation settings the ESP32 reads from Firebase | `lib/screens/automation_screen.dart` → `/smartHome/settings` |
| Clean structure: `screens/ models/ widgets/ services/` | `lib/` |
| All Firebase logic in services | `lib/services/*_service.dart` |
| Loading / empty / error / no-internet / device-offline states | `lib/widgets/state_views.dart` |
| No hard-coded credentials | login screen; API key via `--dart-define-from-file` |
| Each student's module section | module cards show the owner (`lib/config/team.dart`) |
| **Bonus** push notifications (FCM) | `lib/services/notification_service.dart` + `functions/index.js` |
| **Bonus** charts, dark mode, admin/user roles | History tab (fl_chart), Settings → Appearance, Settings → Users and roles |
| **Bonus** scheduling | Automation → Schedules (ESP32 runs them on its NTP clock) |
| **Bonus** history | History tab (`/smartHome/history`, one reading every 30 s) |

Edit `lib/config/team.dart` to put your names on the modules.

### Firebase setup for the full feature set

1. **Device account** for the ESP32: create `esp32-device@calmhills.local` (Firebase console → Authentication → Add user), put its password in `DEVICE_PASSWORD` in the firmware, and flash.
2. **Security rules** (`database.rules.json`: only signed-in users; settings/schedules admin-only): `npx firebase-tools deploy --only database`. Flash the firmware from step 1 *first*, or the board loses access.
3. **First admin**: `npx firebase-tools database:set /users/<uid>/role --data '"admin"'` (uid from Authentication → Users). Admins can promote others in Settings.
4. **Push notifications**: `cd functions && npm install && cd .. && npx firebase-tools deploy --only functions` (needs the Blaze plan; usage stays within the free tier).

## Voice agent ("Hey Home")

Both apps include a voice agent. Speak (or type) commands like *"open the garage door"*, *"close the window"*, *"turn on the fan"* (mobile app only), *"turn on the porch and hall lights"*, *"silence the alarm"*, or ask *"is the garage open?"* / *"is there a fire?"*.

- **Hybrid brain:** an offline command parser (`web/voice/parser.js`, `mobile/.../lib/voice/command_parser.dart`, kept in sync) handles direct commands instantly. Free-form requests ("it's getting dark outside, make the garden bright", "get the house ready for bed") go to an LLM on NVIDIA NIM (`nvidia/nemotron-3.5-lightning-30b-a3b`). The LLM must return JSON that matches a schema, and the app rejects any command key it doesn't recognise.
- **Modes:** tap the mic (tap-to-talk), or switch on **hands-free**, which listens continuously and acts only on phrases starting with "Hey Home" (or "Home, …").
- Every voice command is written to `/smartHome/voice/last`, so the web desk shows commands spoken on the phone.

### API key (never commit it)

| App | Where the key goes |
|-----|--------------------|
| Flutter | `mobile/smart_home_app/secrets.json` → `{"NVIDIA_API_KEY": "nvapi-..."}` (copy `secrets.example.json`), then `flutter run --dart-define-from-file=secrets.json` |
| Web | `tools/.env` → `NVIDIA_API_KEY=nvapi-...` (copy `tools/.env.example`), then `node tools/voice-proxy.mjs` |

Browsers can't call the NVIDIA API directly (it sends no CORS headers), and a key inside the hosted site would be public. So the web dashboard talks to a small local proxy on `http://localhost:8787`. It detects the proxy automatically; without it, the dashboard falls back to offline commands. Web voice input needs Chrome or Edge.

### Tests

```bash
node --test web/voice/parser.test.mjs
cd mobile/smart_home_app && flutter test
```

## Hardware tomorrow

See [`docs/WIRING.md`](docs/WIRING.md). Use external **5V ≥2A** for servos + common GND (not a raw 9V battery).
