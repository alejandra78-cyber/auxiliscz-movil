import 'package:flutter/material.dart';

import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/recover_password_screen.dart';
import '../features/auth/pages/register_screen.dart';
import '../features/emergencias/pages/emergency_status_screen.dart';
import '../features/emergencias/pages/report_emergency_screen.dart';
import '../features/home/pages/home_screen.dart';
import '../features/tecnico/pages/tecnico_tracking_screen.dart';
import '../features/vehiculos/pages/register_vehicle_screen.dart';
//import '../features/cliente/pages/history_screen.dart';
//import '../features/pagos/pages/payment_screen.dart';
//import '../features/calificaciones/pages/evaluate_service_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const recover = '/recover';
  static const home = '/home';
  static const vehiculoRegister = '/vehiculo/register';
  static const emergenciaReport = '/emergencia/report';
  static const emergenciaStatus = '/emergencia-status';
  static const tecnicoTracking = '/tecnico/tracking';
  static const historial = '/cliente/historial';
  static const pago = '/cliente/pago';
  static const evaluar = '/cliente/evaluar';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        recover: (context) => const RecoverPasswordScreen(),
        home: (context) => const HomeScreen(),
        vehiculoRegister: (context) => const RegisterVehicleScreen(),
        emergenciaReport: (context) => const ReportEmergencyScreen(),
        tecnicoTracking: (context) => const TecnicoTrackingScreen(),
        //historial: (context) => const HistoryScreen(),
        //pago: (context) => const PaymentScreen(),
        //evaluar: (context) => const EvaluateServiceScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == emergenciaStatus) {
      final incidenteId = settings.arguments as String;
      return MaterialPageRoute(
        builder: (_) => EmergencyStatusScreen(incidenteId: incidenteId),
      );
    }
    return null;
  }
}
