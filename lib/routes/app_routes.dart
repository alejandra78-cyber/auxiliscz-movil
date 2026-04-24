import 'package:flutter/material.dart';

import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/recover_password_screen.dart';
import '../features/auth/pages/register_screen.dart';
import '../features/emergencias/pages/emergency_status_screen.dart';
import '../features/emergencias/pages/report_emergency_screen.dart';
import '../features/home/pages/home_screen.dart';
import '../features/tecnico/pages/tecnico_tracking_screen.dart';
import '../features/vehiculos/pages/register_vehicle_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const recover = '/recover';
  static const home = '/home';
  static const vehiculoRegister = '/vehiculo/register';
  static const emergenciaReport = '/emergencia/report';
  static const emergenciaStatus = '/emergencia-status';
  static const tecnicoTracking = '/tecnico/tracking';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        recover: (context) => RecoverPasswordScreen(
              initialToken: _tokenFromArgs(ModalRoute.of(context)?.settings.arguments),
            ),
        home: (context) => const HomeScreen(),
        vehiculoRegister: (context) => const RegisterVehicleScreen(),
        emergenciaReport: (context) => const ReportEmergencyScreen(),
        tecnicoTracking: (context) => const TecnicoTrackingScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name != null && settings.name!.startsWith(recover)) {
      final uri = Uri.tryParse(settings.name!);
      final token = uri?.queryParameters['reset_token'];
      return MaterialPageRoute(
        builder: (_) => RecoverPasswordScreen(initialToken: token),
        settings: settings,
      );
    }
    if (settings.name == emergenciaStatus) {
      final incidenteId = (settings.arguments is String)
          ? (settings.arguments as String)
          : '';
      return MaterialPageRoute(
        builder: (_) => EmergencyStatusScreen(incidenteId: incidenteId),
      );
    }
    return null;
  }

  static String? _tokenFromArgs(Object? args) {
    if (args is String && args.trim().isNotEmpty) return args.trim();
    if (args is Map<String, dynamic>) {
      final token = args['reset_token'] ?? args['token'];
      if (token is String && token.trim().isNotEmpty) return token.trim();
    }
    return null;
  }
}
