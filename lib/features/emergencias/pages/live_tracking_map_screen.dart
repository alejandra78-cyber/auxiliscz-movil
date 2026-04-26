import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'live_tracking_map_screen.dart';
import '../services/emergencias_api.dart';

class LiveTrackingMapScreen extends StatefulWidget {
  final String incidenteId;
  final double clienteLat;
  final double clienteLng;

  const LiveTrackingMapScreen({
    super.key,
    required this.incidenteId,
    required this.clienteLat,
    required this.clienteLng,
  });

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final _api = EmergenciesApi();
  final _mapController = MapController();

  Timer? _timer;
  LatLng? _tecnico;
  String _tecnicoNombre = 'Técnico';
  bool _loading = true;

  LatLng get _cliente => LatLng(widget.clienteLat, widget.clienteLng);

  @override
  void initState() {
    super.initState();
    _cargarUbicacion();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cargarUbicacion(),
    );
  }

  Future<void> _cargarUbicacion() async {
    try {
      final data = await _api.getTechnicianLocation(widget.incidenteId);

      final lat = double.tryParse(data['lat']?.toString() ?? '');
      final lng = double.tryParse(data['lng']?.toString() ?? '');

      if (!mounted) return;

      setState(() {
        if (lat != null && lng != null) {
          _tecnico = LatLng(lat, lng);
        }
        _tecnicoNombre = data['tecnico_nombre']?.toString() ?? 'Técnico';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tecnico = _tecnico;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento en tiempo real'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: tecnico ?? _cliente,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.auxilioscz.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _cliente,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 46,
                      ),
                    ),
                    if (tecnico != null)
                      Marker(
                        point: tecnico,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.engineering,
                          size: 46,
                        ),
                      ),
                  ],
                ),
                if (tecnico != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_cliente, tecnico],
                        strokeWidth: 4,
                      ),
                    ],
                  ),
              ],
            ),
      bottomNavigationBar: tecnico == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no hay ubicación del técnico'),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '$_tecnicoNombre actualizado cada 5 segundos',
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}
