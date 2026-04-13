import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();
  bool _initialized = false;
  String? _cachedToken;

  String get platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase no inicializado: $e');
      return false;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? '(sin título)';
        debugPrint('Push recibida en foreground: $title');
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _cachedToken = token;
      });
    } catch (e) {
      debugPrint('No se pudo configurar Firebase Messaging: $e');
    }
    return true;
  }

  Future<String?> getDeviceToken() async {
    final ready = await initialize();
    if (!ready) return null;
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    try {
      _cachedToken = await FirebaseMessaging.instance.getToken();
      return _cachedToken;
    } catch (e) {
      debugPrint('No se pudo obtener token FCM: $e');
      return null;
    }
  }
}
