import 'package:flutter/material.dart';

import 'core/storage/token_storage.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/recover_password_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/emergencies/presentation/screens/emergency_status_screen.dart';
import 'features/emergencies/presentation/screens/report_emergency_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/vehicles/presentation/screens/register_vehicle_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const AuxiliSczApp());
}

class AuxiliSczApp extends StatelessWidget {
  const AuxiliSczApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuxiliSCZ',
      theme: buildAppTheme(),
      home: const _BootstrapScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/recover': (context) => const RecoverPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/vehicle/register': (context) => const RegisterVehicleScreen(),
        '/emergency/report': (context) => const ReportEmergencyScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/emergency-status') {
          final incidenteId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => EmergencyStatusScreen(incidenteId: incidenteId),
          );
        }
        return null;
      },
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
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
