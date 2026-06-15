import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/api_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages with notification payload are shown automatically by Android
}

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (shows dialog on Android 13+, auto-granted on older)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToServer(newToken);
    });
  }

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      print('FCM token error: $e');
    }
  }

  static Future<void> _sendTokenToServer(String fcmToken) async {
    await ApiHelper.updateFcmToken(fcmToken);
  }

  static Future<bool> requestPermissionIfNeeded() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    if (result.isGranted) {
      await _registerToken();
      return true;
    }
    return false;
  }
}
