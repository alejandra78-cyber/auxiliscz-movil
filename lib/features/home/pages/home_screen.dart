import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';

import '../../auth/services/auth_api.dart';
import '../../emergencias/services/emergencias_api.dart';
import '../../viaje/services/travel_mode_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _role = '';
  final _travelMode = TravelModeController.instance;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _travelMode.addListener(_onTravelModeChanged);
    _travelMode.cargarEstado();
  }

  @override
  void dispose() {
    _travelMode.removeListener(_onTravelModeChanged);
    super.dispose();
  }

  void _onTravelModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleModoViaje(bool activar) async {
    if (!activar) {
      await _travelMode.desactivar();
      return;
    }

    final permiso = await _travelMode.solicitarPermisos();
    if (!mounted) return;

    switch (permiso) {
      case PermisoUbicacionResultado.concedido:
        await _travelMode.activar();
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.modoViaje);
        return;
      case PermisoUbicacionResultado.gpsDesactivado:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa el GPS para usar el Modo Viaje'),
          ),
        );
        return;
      case PermisoUbicacionResultado.denegado:
      case PermisoUbicacionResultado.denegadoPermanente:
        final permanente =
            permiso == PermisoUbicacionResultado.denegadoPermanente;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso de ubicación necesario'),
            content: Text(
              permanente
                  ? 'El permiso de ubicación fue denegado permanentemente. '
                      'Para usar el Modo Viaje, habilítalo desde la '
                      'configuración de la aplicación.'
                  : 'El Modo Viaje necesita tu ubicación para mostrar el mapa '
                      'y calcular la ruta hacia tu destino. Sin este permiso '
                      'no es posible activarlo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
              if (permanente)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('Abrir configuración'),
                ),
            ],
          ),
        );
        return;
    }
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
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return (map['rol'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openConsulta(BuildContext context) async {
    final api = EmergenciesApi();
    String? incidenteId;
    try {
      final latest = await api.getLatestEmergencyStatus();
      incidenteId = (latest['incidente_id'] ?? '').toString().trim();
      if (!context.mounted) return;
      if (incidenteId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró una solicitud para consultar'),
          ),
        );
        return;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.emergenciaStatus,
      arguments: incidenteId,
    );
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
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
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
                children: [
                  const Text(
                    'Plataforma de emergencias vehiculares',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rol actual: ${_role.isEmpty ? 'sin definir' : _role}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (!_isTecnico) ...[
            Card(
              child: SwitchListTile(
                secondary: Icon(
                  Icons.route,
                  color: _travelMode.activo ? AppColors.accent : null,
                ),
                title: const Text(
                  'Modo Viaje',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _travelMode.activo
                      ? 'Activo · toca para abrir el mapa'
                      : 'Activar Modo Viaje',
                ),
                value: _travelMode.activo,
                onChanged: _toggleModoViaje,
              ),
            ),
            if (_travelMode.activo) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.modoViaje),
                icon: const Icon(Icons.map),
                label: const Text('Abrir pantalla de viaje'),
              ),
            ],
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.vehiculoRegister),
              icon: const Icon(Icons.directions_car),
              label: const Text('Registrar vehículo'),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.emergenciaReport),
              icon: const Icon(Icons.emergency_share),
              label: const Text('Reportar emergencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => _openConsulta(context),
              icon: const Icon(Icons.search),
              label: const Text('Consultar emergencia'),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.historial),
              icon: const Icon(Icons.history),
              label: const Text('Historial de servicios'),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.pago),
              icon: const Icon(Icons.payments),
              label: const Text('Procesar pago'),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.evaluar),
              icon: const Icon(Icons.star),
              label: const Text('Evaluar servicio'),
            ),
          ],

          if (_isTecnico) ...[
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.tecnicoTracking),
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
