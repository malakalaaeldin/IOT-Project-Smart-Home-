import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Alert notifications.
///
/// * Push (FCM): the phone subscribes to the "alerts" topic; the Cloud
///   Function in /functions sends fire/rain pushes even when the app is closed.
/// * Local: while the app is open, alerts seen in the live data are shown as
///   notifications too. Both use the same id per alert type, so they replace
///   each other instead of appearing twice.
class NotificationService {
  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'alerts',
    'Critical alerts',
    description: 'Fire and rain alerts from the smart home',
    importance: Importance.max,
  );

  static const idFire = 1;
  static const idRain = 2;

  bool pushReady = false;
  String? pushError;
  String? token;

  Future<void> init() async {
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('local notifications: $e');
    }

    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      await fcm.subscribeToTopic('alerts');
      token = await fcm.getToken();
      pushReady = true;
      // In the foreground Android doesn't show FCM notifications itself.
      FirebaseMessaging.onMessage.listen((m) {
        final type = m.data['type'];
        show(
          type == 'rain' ? idRain : idFire,
          m.notification?.title ?? 'Smart home alert',
          m.notification?.body ?? '',
        );
      });
    } catch (e) {
      pushError = e.toString();
      debugPrint('FCM: $e');
    }
  }

  Future<void> show(int id, String title, String body) async {
    try {
      await _local.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('show notification: $e');
    }
  }
}
