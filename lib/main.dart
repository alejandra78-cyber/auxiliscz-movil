import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'features/auth/pages/login_screen.dart';
import 'features/viaje/services/crash_alert_listener.dart';
import 'routes/app_routes.dart'; // 👈 ESTE FALTABA
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Detección de choques: solo Android (foreground service + sensores).
  // En web no existe el servicio, así que evitamos invocarlo.
  if (!kIsWeb) {
    // Canal de comunicación UI ↔ aislado del Foreground Service.
    FlutterForegroundTask.initCommunicationPort();
    initCrashAlertUi();
  }
  runApp(const AuxiliSczApp());
}

class AuxiliSczApp extends StatelessWidget {
  const AuxiliSczApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuxiliSCZ',
      navigatorKey: crashNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
