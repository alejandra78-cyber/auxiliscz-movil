import 'package:flutter/material.dart';

import '../features/auth/pages/login_screen.dart';
import '../features/auth/pages/recover_password_screen.dart';
import '../features/auth/pages/register_screen.dart';
import '../features/clientes_vehiculos/pages/quote_comparison_screen.dart';
import '../features/clientes_vehiculos/pages/register_vehicle_screen.dart';
import '../features/clientes_vehiculos/pages/workshop_recommendation_screen.dart';
import '../features/emergencias/pages/emergency_status_screen.dart';
import '../features/emergencias/pages/notifications_screen.dart';
import '../features/historial/pages/history_services_screen.dart';
import '../features/emergencias/pages/report_emergency_screen.dart';
import '../features/emergencias/pages/request_chat_screen.dart';
import '../features/home/pages/home_screen.dart';
import '../features/seguimiento/pages/technician_location_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const recover = '/recover';
  static const home = '/home';
  static const vehiculoRegister = '/vehiculo/register';
  static const emergenciaReport = '/emergencia/report';
  static const emergenciaStatus = '/emergencia-status';
  static const cotizacionesComparar = '/cliente/cotizaciones/comparar';
  static const recomendacionTalleres = '/cliente/cotizaciones/recomendacion';
  static const tecnicoLocation = '/tecnico/location';
  static const serviciosHistorial = '/cliente/historial-servicios';
  static const solicitudChat = '/solicitud/chat';
  static const notificaciones = '/notificaciones';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        recover: (context) => RecoverPasswordScreen(
              initialToken: _tokenFromArgs(ModalRoute.of(context)?.settings.arguments),
            ),
        home: (context) => const HomeScreen(),
        vehiculoRegister: (context) => const RegisterVehicleScreen(),
        emergenciaReport: (context) => const ReportEmergencyScreen(),
        serviciosHistorial: (context) => const HistoryServicesScreen(),
        notificaciones: (context) => const NotificationsScreen(),
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
    if (settings.name == tecnicoLocation) {
      final incidenteId = (settings.arguments is String)
          ? (settings.arguments as String)
          : '';
      return MaterialPageRoute(
        builder: (_) => TechnicianLocationScreen(incidenteId: incidenteId),
      );
    }
    if (settings.name == cotizacionesComparar) {
      final incidenteId = (settings.arguments is String)
          ? (settings.arguments as String)
          : '';
      return MaterialPageRoute(
        builder: (_) => QuoteComparisonScreen(incidenteId: incidenteId),
      );
    }
    if (settings.name == recomendacionTalleres) {
      final incidenteId = (settings.arguments is String)
          ? (settings.arguments as String)
          : '';
      return MaterialPageRoute(
        builder: (_) => WorkshopRecommendationScreen(incidenteId: incidenteId),
      );
    }
    if (settings.name == solicitudChat) {
      final incidenteId = (settings.arguments is String)
          ? (settings.arguments as String)
          : '';
      return MaterialPageRoute(
        builder: (_) => RequestChatScreen(incidenteId: incidenteId),
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
