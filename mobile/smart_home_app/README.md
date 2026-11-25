# Calm Hills Smart Home (Flutter)

Android package: `com.calmhills.smarthome`

## Prerequisites

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows) and add it to PATH.
2. Start an Android emulator (or plug in a device).
3. Ensure Email/Password Auth is enabled in the [Firebase console](https://console.firebase.google.com/project/calm-hills-smart-home/authentication/providers).

`google-services.json` and `lib/firebase_options.dart` are already filled for project **calm-hills-smart-home**.

## Run

```bash
cd mobile/smart_home_app
flutter create . --project-name smart_home_app --org com.calmhills
flutter pub get
flutter run
```

`flutter create .` fills any missing Android/iOS scaffolding without overwriting `lib/` if you keep existing files when prompted.

Create an account in the app, then use the dashboard. Commands write to `/smartHome/commands` in Realtime Database.
