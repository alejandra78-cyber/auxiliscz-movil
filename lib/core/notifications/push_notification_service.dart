import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/auth/services/auth_api.dart';
import '../../firebase_options.dart';
import '../../routes/app_routes.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel auxilioPushChannel = AndroidNotificationChannel(
  'auxilioscz_alertas',
  'Alertas AuxilioSCZ',
  description: 'Notificaciones importantes de solicitudes, pagos, técnico y chat.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || Firebase.apps.isEmpty) return;

    await _initializeLocalNotifications();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
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

  Future<void> _initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final parts = payload.split('|');
        final tipo = parts.isNotEmpty ? parts[0] : '';
        final id = parts.length > 1 ? parts[1] : '';
        _openByData(tipo: tipo, id: id);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(auxilioPushChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> registerCurrentDeviceToken({String? tokenOverride}) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final token = tokenOverride ??
          await _messaging.getToken().timeout(
                const Duration(seconds: 8),
              );
      if (token == null || token.trim().isEmpty) return;
      debugPrint('Registrando token push $_platformName: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');
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
    debugPrint('Push foreground recibido tipo=${message.data['tipo']} solicitud=${message.data['solicitud_id'] ?? message.data['incidente_id']}');
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('Push foreground: $title - $body');
      return;
    }
    _showLocalForegroundNotification(message, title, body);
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

  Future<void> _showLocalForegroundNotification(RemoteMessage message, String title, String body) async {
    final tipo = (message.data['tipo'] ?? 'sistema').toString();
    final id = (message.data['incidente_id'] ?? message.data['solicitud_id'] ?? '').toString();
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'auxilioscz_alertas',
          'Alertas AuxilioSCZ',
          channelDescription: 'Notificaciones importantes de AuxilioSCZ.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.message,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: '$tipo|$id',
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
    _openByData(tipo: tipo, id: id);
  }

  void _openByData({required String tipo, required String id}) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
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
