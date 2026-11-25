// Placeholder — replaced after Firebase Android/Web apps are registered.
// Run: dart pub global activate flutterfire_cli && flutterfire configure
// Or paste values from the Firebase console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android; // Android-first project; iOS not configured yet
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDW9RtinDZKjAPELdYUemKgEDgdH1Ihlg8',
    appId: '1:260254281081:web:eb0cfe0218615e729d13a8',
    messagingSenderId: '260254281081',
    projectId: 'calm-hills-smart-home',
    authDomain: 'calm-hills-smart-home.firebaseapp.com',
    databaseURL:
        'https://calm-hills-smart-home-default-rtdb.firebaseio.com',
    storageBucket: 'calm-hills-smart-home.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCnMLPJlporey04h78JuM6uqjqiQPTubGs',
    appId: '1:260254281081:android:a849201f2f9e96f09d13a8',
    messagingSenderId: '260254281081',
    projectId: 'calm-hills-smart-home',
    databaseURL:
        'https://calm-hills-smart-home-default-rtdb.firebaseio.com',
    storageBucket: 'calm-hills-smart-home.firebasestorage.app',
  );
}
