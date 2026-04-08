import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/emergencia_screen.dart';
import 'screens/seguimiento_screen.dart';
import 'screens/calificacion_screen.dart';

void main() {
  runApp(const AuxilioSCZApp());
}

class AuxilioSCZApp extends StatelessWidget {
  const AuxilioSCZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuxilioSCZ',
      theme: ThemeData(
        primaryColor: const Color(0xFF1f3a7a),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1f3a7a),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      routes: {
        '/emergencia': (context) => const EmergenciaScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/seguimiento') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => SeguimientoScreen(
              incidenteId: args['incidenteId'],
              latCliente: args['latCliente'],
              lngCliente: args['lngCliente'],
            ),
          );
        }
        if (settings.name == '/calificacion') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CalificacionScreen(
              incidenteId: args['incidenteId'],
              nombreTaller: args['nombreTaller'],
            ),
          );
        }
        return null;
      },
    );
  }
}
