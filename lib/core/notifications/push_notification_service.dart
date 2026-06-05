import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/auth/services/auth_api.dart';
import '../../firebase_options.dart';
import '../../routes/app_routes.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || Firebase.apps.isEmpty) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setAutoInitEnabled(true);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromMessage(initialMessage));
    }

    _messaging.onTokenRefresh.listen((token) {
      registerCurrentDeviceToken(tokenOverride: token);
    });

    _initialized = true;
  }

  Future<void> registerCurrentDeviceToken({String? tokenOverride}) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final token = tokenOverride ??
          await _messaging.getToken().timeout(
                const Duration(seconds: 8),
              );
      if (token == null || token.trim().isEmpty) return;
      await AuthApi()
          .registerDeviceToken(
            token: token,
            plataforma: _platformName,
          )
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('No se pudo registrar token push: $error');
    }
  }

  Future<void> removeCurrentDeviceToken() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await _messaging.getToken().timeout(const Duration(seconds: 8));
      if (token == null || token.trim().isEmpty) return;
      await AuthApi()
          .removeDeviceToken(token: token, plataforma: _platformName)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('No se pudo desactivar token push: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['titulo']?.toString() ?? 'AuxilioSCZ';
    final body = notification?.body ?? message.data['cuerpo']?.toString() ?? 'Tienes una nueva actualización';
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('Push foreground: $title - $body');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _openFromMessage(message),
        ),
      ),
    );
  }

  void _openFromMessage(RemoteMessage message) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final data = message.data;
    final tipo = (data['tipo'] ?? '').toString();
    final solicitudId = (data['solicitud_id'] ?? '').toString();
    final incidenteId = (data['incidente_id'] ?? solicitudId).toString();
    final id = incidenteId.trim().isNotEmpty ? incidenteId.trim() : solicitudId.trim();

    if (id.isEmpty) {
      navigator.pushNamed(AppRoutes.home);
      return;
    }
    if (tipo.contains('chat') || tipo.contains('mensaje')) {
      navigator.pushNamed(AppRoutes.solicitudChat, arguments: id);
    } else if (tipo.contains('cotizacion')) {
      navigator.pushNamed(AppRoutes.cotizacionesComparar, arguments: id);
    } else if (tipo.contains('seguimiento')) {
      navigator.pushNamed(AppRoutes.tecnicoLocation, arguments: id);
    } else {
      navigator.pushNamed(AppRoutes.emergenciaStatus, arguments: id);
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web_flutter';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
