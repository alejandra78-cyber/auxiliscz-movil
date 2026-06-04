import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../emergencias/services/emergencias_api.dart';

class TechnicianLocationScreen extends StatefulWidget {
  const TechnicianLocationScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<TechnicianLocationScreen> createState() => _TechnicianLocationScreenState();
}

class _TechnicianLocationScreenState extends State<TechnicianLocationScreen> {
  final _api = EmergenciesApi();
  final _mapCtrl = MapController();
  Timer? _timer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  bool _loading = true;
  String _error = '';
  String _connectionLabel = 'Conectando seguimiento en vivo...';
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
    _connectWebSocket();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    if (widget.incidenteId.trim().isEmpty) return;
    try {
      final uri = Uri.parse('${AppConfig.wsBaseUrl}/api/ws/tracking/${widget.incidenteId}');
      _channel = WebSocketChannel.connect(uri);
      _wsSub = _channel!.stream.listen(
        (event) {
          final decoded = jsonDecode(event.toString());
          if (decoded is! Map<String, dynamic>) return;
          if ((decoded['tipo'] ?? '').toString() != 'ubicacion_tecnico') return;
          if (!mounted) return;
          setState(() {
            _connectionLabel = 'Seguimiento en vivo conectado';
            _error = '';
            _loading = false;
            _data = {
              ...?_data,
              'incidente_id': decoded['incidente_id'] ?? widget.incidenteId,
              'tecnico_nombre': decoded['tecnico_nombre'] ?? _data?['tecnico_nombre'],
              'estado_servicio': decoded['estado_servicio'] ?? _data?['estado_servicio'],
              'latitud_tecnico': decoded['latitud_tecnico'] ?? decoded['lat'] ?? _data?['latitud_tecnico'],
              'longitud_tecnico': decoded['longitud_tecnico'] ?? decoded['lng'] ?? _data?['longitud_tecnico'],
              'latitud_cliente': decoded['latitud_cliente'] ?? _data?['latitud_cliente'],
              'longitud_cliente': decoded['longitud_cliente'] ?? _data?['longitud_cliente'],
              'ultima_actualizacion': decoded['ultima_actualizacion'] ?? decoded['timestamp'],
              'mensaje': decoded['mensaje'] ?? 'Ubicación del técnico actualizada en tiempo real',
            };
          });
          _centrarMapaSiCorresponde();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _connectionLabel = 'Seguimiento por recarga automática';
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connectionLabel = 'Seguimiento por recarga automática';
          });
        },
        cancelOnError: false,
      );
    } catch (_) {
      _connectionLabel = 'Seguimiento por recarga automática';
    }
  }

  Future<void> _load() async {
    if (widget.incidenteId.trim().isEmpty) return;
    try {
      final data = await _api.getTechnicianLocation(widget.incidenteId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = '';
        _loading = false;
      });
      _centrarMapaSiCorresponde();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _centrarMapaSiCorresponde() {
    final d = _data;
    if (d == null) return;
    final latTec = _toDouble(d['latitud_tecnico']);
    final lngTec = _toDouble(d['longitud_tecnico']);
    final latCli = _toDouble(d['latitud_cliente']);
    final lngCli = _toDouble(d['longitud_cliente']);
    final targetLat = latTec ?? latCli;
    final targetLng = lngTec ?? lngCli;
    if (targetLat != null && targetLng != null) {
      _mapCtrl.move(LatLng(targetLat, targetLng), 14);
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? const <String, dynamic>{};
    final latTec = _toDouble(d['latitud_tecnico']);
    final lngTec = _toDouble(d['longitud_tecnico']);
    final latCli = _toDouble(d['latitud_cliente']);
    final lngCli = _toDouble(d['longitud_cliente']);
    final points = <LatLng>[
      if (latCli != null && lngCli != null) LatLng(latCli, lngCli),
      if (latTec != null && lngTec != null) LatLng(latTec, lngTec),
    ];
    final hasMap = points.isNotEmpty;
    final mapCenter = points.isNotEmpty ? points.first : const LatLng(-17.7833, -63.1821);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación del técnico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: AppColors.danger)),
          ],
          SectionCard(
            title: 'Seguimiento en tiempo real',
            subtitle: _connectionLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Técnico: ${d['tecnico_nombre'] ?? '-'}'),
                Text('Estado: ${d['estado_servicio'] ?? '-'}'),
                Text('Última actualización: ${d['ultima_actualizacion'] ?? '-'}'),
                if ((d['mensaje'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      d['mensaje'].toString(),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                const SizedBox(height: 10),
                if (!hasMap)
                  const Text('El técnico aún no inició el seguimiento.')
                else
                  SizedBox(
                    height: 320,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: _mapCtrl,
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.auxilioscz.app',
                          ),
                          if (latCli != null && lngCli != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(latCli, lngCli),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                                ),
                              ],
                            ),
                          if (latTec != null && lngTec != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(latTec, lngTec),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.engineering, color: Colors.red, size: 38),
                                ),
                              ],
                            ),
                          if (latCli != null && lngCli != null && latTec != null && lngTec != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [LatLng(latCli, lngCli), LatLng(latTec, lngTec)],
                                  strokeWidth: 4,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
