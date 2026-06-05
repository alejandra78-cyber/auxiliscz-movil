import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/notifications/push_notification_service.dart';
import 'core/storage/token_storage.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await PushNotificationService.instance.initialize();
  } on UnsupportedError catch (error) {
    debugPrint('Firebase no configurado para esta plataforma: $error');
  } catch (error) {
    debugPrint('No se pudo inicializar Firebase: $error');
  }
  runApp(const AuxiliSczApp());
}

class AuxiliSczApp extends StatelessWidget {
  const AuxiliSczApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuxiliSCZ',
      navigatorKey: appNavigatorKey,
      theme: buildAppTheme(),
      home: const _BootstrapScreen(),
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await TokenStorage().readToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      unawaited(PushNotificationService.instance.registerCurrentDeviceToken());
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
