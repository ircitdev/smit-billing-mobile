import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../app_keys.dart';
import '../models/video_object.dart';
import '../screens/video_events_screen.dart';
import 'api_client.dart';

class PushService {
  final ApiClient _api;

  PushService(this._api);

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get APNS token first on iOS (required before FCM token)
    if (Platform.isIOS) {
      await messaging.getAPNSToken();
    }

    // Get FCM token and register on server
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_registerToken);

    // build 3662: нажатие на push о событии камеры — открыть ленту событий объекта
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromPush);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // приложение запущено нажатием на уведомление — даём главному экрану построиться
      Future.delayed(const Duration(milliseconds: 900), () => _openFromPush(initial));
    }
    // приложение открыто: системное уведомление на Android не показывается — показываем плашку
    FirebaseMessaging.onMessage.listen((m) {
      if (m.data['type'] != 'video_event') return;
      appMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(m.notification?.body ?? m.notification?.title ?? 'Событие камеры'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Открыть', onPressed: () => _openFromPush(m)),
      ));
    });
  }

  Future<void> _openFromPush(RemoteMessage m) async {
    if (m.data['type'] != 'video_event') return;
    final objectId = int.tryParse('${m.data['object_id'] ?? ''}');
    if (objectId == null) return;
    try {
      final data = await _api.get('/video/objects');
      final objects = ((data['items'] ?? []) as List)
          .map((e) => VideoObjectModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final obj = objects.where((o) => o.id == objectId).firstOrNull;
      if (obj == null) return;
      final cameraId = int.tryParse('${m.data['camera_id'] ?? ''}');
      appNavigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => VideoEventsScreen(object: obj, cameraId: cameraId),
      ));
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _api.post('/push/register', {
        'token': token,
        'platform': platform,
      });
    } catch (_) {}
  }
}
