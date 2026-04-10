import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/emergencies_api.dart';

class EmergencyStatusScreen extends StatefulWidget {
  const EmergencyStatusScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<EmergencyStatusScreen> createState() => _EmergencyStatusScreenState();
}

class _EmergencyStatusScreenState extends State<EmergencyStatusScreen> {
  final _api = EmergenciesApi();
  Map<String, dynamic>? _estado;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.getEmergencyStatus(widget.incidenteId);
      if (!mounted) return;
      setState(() => _estado = data);
    } catch (_) {}
  }

  Future<void> _sendGpsAgain() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      await _api.sendGps(
        incidenteId: widget.incidenteId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación enviada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de solicitud')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incidente: ${widget.incidenteId}'),
            const SizedBox(height: 8),
            Text('Estado: ${_estado?['estado'] ?? 'consultando...'}'),
            const SizedBox(height: 8),
            Text('Tipo: ${_estado?['tipo'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Prioridad: ${_estado?['prioridad'] ?? '-'}'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _sendGpsAgain, child: const Text('Enviar ubicación GPS nuevamente')),
          ],
        ),
      ),
    );
  }
}
