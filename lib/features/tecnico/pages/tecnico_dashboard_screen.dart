import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../emergencias/services/emergencias_api.dart';

class TecnicoDashboardScreen extends StatefulWidget {
  const TecnicoDashboardScreen({super.key});

  @override
  State<TecnicoDashboardScreen> createState() => _TecnicoDashboardScreenState();
}

class _TecnicoDashboardScreenState extends State<TecnicoDashboardScreen> {
  final _api = EmergenciesApi();
  bool _loading = true;
  bool _sendingLocation = false;
  List<Map<String, dynamic>> _servicios = [];

  @override
  void initState() {
    super.initState();
    _loadServicios();
  }

  Future<void> _loadServicios() async {
    try {
      final data = await _api.getMyActiveServicesAsTechnician();
      if (!mounted) return;
      setState(() {
        _servicios = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _enviarUbicacion() async {
    setState(() => _sendingLocation = true);

    try {
      final permiso = await Geolocator.requestPermission();

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado');
      }

      final pos = await Geolocator.getCurrentPosition();

      await _api.updateMyTechnicianLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación enviada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _sendingLocation = false);
    }
  }

  Future<void> _completarServicio(String incidenteId) async {
    try {
      await _api.completeTechnicianService(incidenteId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio completado')),
      );

      _loadServicios();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel técnico'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadServicios,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ElevatedButton.icon(
                    onPressed: _sendingLocation ? null : _enviarUbicacion,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _sendingLocation
                          ? 'Enviando ubicación...'
                          : 'Compartir mi ubicación',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Servicios asignados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_servicios.isEmpty)
                    const Text('No tienes servicios activos')
                  else
                    ..._servicios.map((s) {
                      final incidenteId =
                          (s['incidente_id'] ?? s['solicitud_id'] ?? '')
                              .toString();

                      return Card(
                        child: ListTile(
                          title: Text(
                            s['codigo_solicitud']?.toString() ??
                                'Servicio asignado',
                          ),
                          subtitle: Text(
                            'Estado: ${s['estado'] ?? '-'}\n'
                            'Tipo: ${s['tipo'] ?? s['servicio'] ?? '-'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle),
                            onPressed: incidenteId.isEmpty
                                ? null
                                : () => _completarServicio(incidenteId),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
