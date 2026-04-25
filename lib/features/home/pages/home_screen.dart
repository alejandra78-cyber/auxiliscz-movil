import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/services/auth_api.dart';
import '../../emergencias/services/emergencias_api.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _role = '';
  bool _openingConsulta = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final token = await AuthApi().getToken();
    if (!mounted || token == null || token.isEmpty) return;
    final role = _extractRole(token);
    setState(() => _role = role);
  }

  String _extractRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return (map['rol'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openConsulta(BuildContext context) async {
    if (_openingConsulta) return;
    setState(() => _openingConsulta = true);
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
        if (mounted) setState(() => _openingConsulta = false);
        return;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) setState(() => _openingConsulta = false);
      return;
    }
    if (!context.mounted) {
      if (mounted) setState(() => _openingConsulta = false);
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: incidenteId);
    if (mounted) setState(() => _openingConsulta = false);
  }

  bool get _isTecnico => _role == 'tecnico';

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
          SectionCard(
            title: 'Panel del Cliente',
            subtitle: 'Plataforma de emergencias vehiculares',
            icon: Icons.dashboard_customize_outlined,
            child: Text(
              'Rol actual: ${_role.isEmpty ? 'sin definir' : _role}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isTecnico) ...[
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
              onPressed: _openingConsulta ? null : () => _openConsulta(context),
              icon: const Icon(Icons.search),
              label: Text(_openingConsulta ? 'Abriendo...' : 'Consultar emergencia'),
            ),
          ],
          if (_isTecnico) ...[
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.tecnicoTracking),
              icon: const Icon(Icons.location_searching),
              label: const Text('Compartir ubicación en tiempo real'),
            ),
          ],
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

