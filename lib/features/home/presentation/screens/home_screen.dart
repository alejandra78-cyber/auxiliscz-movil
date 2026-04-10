import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../../shared/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
            onPressed: () => Navigator.pushNamed(context, '/vehicle/register'),
            icon: const Icon(Icons.directions_car),
            label: const Text('Registrar vehículo (CU10)'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/emergency/report'),
            icon: const Icon(Icons.emergency_share),
            label: const Text('Reportar emergencia (CU11-CU13)'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/recover'),
            icon: const Icon(Icons.lock_reset),
            label: const Text('Recuperar contraseña (CU05)'),
          ),
        ],
      ),
    );
  }
}
