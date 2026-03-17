import 'package:firebase_messaging/firebase_messaging.dart';
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

    // Get FCM token and register on server
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.post('/push/register', {
        'token': token,
        'platform': 'android', // TODO: detect platform
      });
    } catch (_) {}
  }
}
