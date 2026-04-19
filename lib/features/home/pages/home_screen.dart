import 'package:flutter/material.dart';
import '../../auth/services/auth_api.dart';
import '../../emergencias/services/emergencias_api.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openConsulta(BuildContext context) async {
    final api = EmergenciesApi();
    String? incidenteId;
    try {
      final latest = await api.getLatestEmergencyStatus();
      incidenteId = (latest['incidente_id'] ?? '').toString().trim();
      if (!context.mounted) return;
      if (incidenteId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró una solicitud para consultar')),
        );
        return;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }
    if (!context.mounted) return;
    final resolvedId = incidenteId ?? '';
    if (resolvedId.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: resolvedId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AuxiliSCZ'),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthApi().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Plataforma de emergencias vehiculares', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('Selecciona una acción del ciclo 1.', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.vehiculoRegister),
            icon: const Icon(Icons.directions_car),
            label: const Text('Registrar vehículo'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.emergenciaReport),
            icon: const Icon(Icons.emergency_share),
            label: const Text('Reportar emergencia'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _openConsulta(context),
            icon: const Icon(Icons.search),
            label: const Text('Consultar emergencia'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.recover),
            icon: const Icon(Icons.lock_reset),
            label: const Text('Recuperar contraseña'),
          ),
        ],
      ),
    );
  }
}
