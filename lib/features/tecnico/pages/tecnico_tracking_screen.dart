import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../emergencias/services/emergencias_api.dart';

class TecnicoTrackingScreen extends StatefulWidget {
  const TecnicoTrackingScreen({super.key});

  @override
  State<TecnicoTrackingScreen> createState() => _TecnicoTrackingScreenState();
}

class _TecnicoTrackingScreenState extends State<TecnicoTrackingScreen> {
  final _api = EmergenciesApi();
  Timer? _timer;
  bool _sending = false;
  bool _auto = false;
  String _msg = 'Presiona "Actualizar ahora" para enviar tu ubicación.';
  List<Map<String, dynamic>> _servicios = const [];

  @override
  void initState() {
    super.initState();
    _cargarServicios();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarServicios() async {
    try {
      final rows = await _api.getMyActiveServicesAsTechnician();
      if (!mounted) return;
      setState(() => _servicios = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = '$e');
    }
  }

  Future<void> _enviarUbicacion() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Activa el GPS para compartir ubicación');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado');
      }
      final pos = await Geolocator.getCurrentPosition();
      await _api.updateMyTechnicianLocation(lat: pos.latitude, lng: pos.longitude);
      if (!mounted) return;
      setState(() {
        _msg = 'Ubicación enviada: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggleAuto() {
    if (_auto) {
      _timer?.cancel();
      setState(() => _auto = false);
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _enviarUbicacion());
    setState(() => _auto = true);
    _enviarUbicacion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación en tiempo real (Técnico)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Servicios activos asignados',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_servicios.isEmpty)
            const Text('No tienes servicios activos en este momento.'),
          ..._servicios.map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['codigo_solicitud'] ?? s['incidente_id'] ?? ''}'),
              subtitle: Text('Estado: ${s['estado'] ?? '-'} · Cliente: ${s['cliente'] ?? '-'}'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _sending ? null : _enviarUbicacion,
            child: Text(_sending ? 'Enviando...' : 'Actualizar ahora'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _toggleAuto,
            child: Text(_auto ? 'Detener envío automático' : 'Iniciar envío automático'),
          ),
          const SizedBox(height: 12),
          Text(_msg),
        ],
      ),
    );
  }
}

