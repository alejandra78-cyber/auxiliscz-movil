import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
          final wsLatTec = decoded['latitud_tecnico'] ?? decoded['lat'];
          final wsLngTec = decoded['longitud_tecnico'] ?? decoded['lng'];
          final wsLatCli = decoded['latitud_cliente'];
          final wsLngCli = decoded['longitud_cliente'];
          final hasCompleteCoords = wsLatTec != null && wsLngTec != null && wsLatCli != null && wsLngCli != null;
          if (!hasCompleteCoords) {
            unawaited(_load());
            return;
          }
          setState(() {
            _connectionLabel = 'Seguimiento en vivo conectado';
            _error = '';
            _loading = false;
            _data = {
              ...?_data,
              'incidente_id': decoded['incidente_id'] ?? widget.incidenteId,
              'tecnico_nombre': decoded['tecnico_nombre'] ?? _data?['tecnico_nombre'],
              'tecnico': {
                ...?_asMap(_data?['tecnico']),
                'nombre': decoded['tecnico_nombre'] ?? _asMap(_data?['tecnico'])?['nombre'],
                'latitud': wsLatTec,
                'longitud': wsLngTec,
              },
              'cliente': {
                ...?_asMap(_data?['cliente']),
                'latitud': wsLatCli,
                'longitud': wsLngCli,
              },
              'estado': decoded['estado'] ?? decoded['estado_servicio'] ?? _data?['estado'],
              'estado_servicio': decoded['estado_servicio'] ?? _data?['estado_servicio'],
              'latitud_tecnico': wsLatTec,
              'longitud_tecnico': wsLngTec,
              'latitud_cliente': wsLatCli,
              'longitud_cliente': wsLngCli,
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  String _estadoVisible(Map<String, dynamic> d, double? distanciaKm) {
    final backend = (d['estado_visible'] ?? '').toString().trim();
    if (backend.isNotEmpty) return backend;
    final estado = (d['estado'] ?? d['estado_servicio'] ?? '').toString().trim().toLowerCase();
    if (estado == 'finalizado') return 'Servicio finalizado';
    if (estado == 'tecnico_en_lugar' || estado == 'en_diagnostico' || estado == 'diagnostico_completado') {
      return 'El técnico llegó al lugar';
    }
    if (estado == 'en_atencion' || estado == 'en_proceso' || estado == 'trabajo_completado') {
      return 'Servicio en atención';
    }
    if (distanciaKm != null && distanciaKm < 0.1) return 'El técnico está llegando';
    if (distanciaKm != null && distanciaKm <= 0.5) return 'El técnico está cerca';
    return 'Técnico en camino';
  }

  String _mensajeVisible(Map<String, dynamic> d, double? distanciaKm) {
    final mensaje = (d['mensaje'] ?? '').toString().trim();
    final estado = (d['estado'] ?? d['estado_servicio'] ?? '').toString().trim().toLowerCase();
    if (estado == 'tecnico_en_lugar' || estado == 'en_diagnostico' || estado == 'diagnostico_completado') {
      return 'El técnico llegó al lugar de la emergencia.';
    }
    if (estado == 'en_atencion' || estado == 'en_proceso' || estado == 'trabajo_completado') {
      return 'El servicio está siendo atendido.';
    }
    if (distanciaKm != null && distanciaKm < 0.1) return 'El técnico está llegando a tu ubicación.';
    if (distanciaKm != null && distanciaKm <= 0.5) return 'El técnico está muy cerca de tu ubicación.';
    if (mensaje.isNotEmpty && !mensaje.contains('_')) return mensaje;
    return 'El técnico se está acercando a tu ubicación.';
  }

  double? _distanciaKm(double? latTec, double? lngTec, double? latCli, double? lngCli, Map<String, dynamic> d) {
    final backend = _toDouble(d['distancia_restante_km']);
    if (backend != null) return backend;
    if (latTec == null || lngTec == null || latCli == null || lngCli == null) return null;
    const radio = 6371.0;
    final dLat = _rad(latCli - latTec);
    final dLng = _rad(lngCli - lngTec);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(latTec)) * math.cos(_rad(latCli)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return radio * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;

  int? _etaMin(double? distanciaKm, Map<String, dynamic> d) {
    final backend = _toDouble(d['tiempo_estimado_llegada_min']);
    if (backend != null) return backend.round().clamp(1, 999).toInt();
    if (distanciaKm == null) return null;
    return math.max(1, ((distanciaKm / 30) * 60).round());
  }

  String _horaCorta(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    final date = parsed?.toLocal();
    if (date == null) return raw.length >= 5 ? raw.substring(0, 5) : raw;
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? const <String, dynamic>{};
    final tecnico = _asMap(d['tecnico']);
    final cliente = _asMap(d['cliente']);
    final latTec = _toDouble(tecnico?['latitud'] ?? d['latitud_tecnico']);
    final lngTec = _toDouble(tecnico?['longitud'] ?? d['longitud_tecnico']);
    final latCli = _toDouble(cliente?['latitud'] ?? d['latitud_cliente']);
    final lngCli = _toDouble(cliente?['longitud'] ?? d['longitud_cliente']);
    final distanciaKm = _distanciaKm(latTec, lngTec, latCli, lngCli, d);
    final etaMin = _etaMin(distanciaKm, d);
    final estadoVisible = _estadoVisible(d, distanciaKm);
    final mensajeVisible = _mensajeVisible(d, distanciaKm);
    final points = <LatLng>[
      if (latCli != null && lngCli != null) LatLng(latCli, lngCli),
      if (latTec != null && lngTec != null) LatLng(latTec, lngTec),
    ];
    final hasMap = points.isNotEmpty;
    final mapCenter = points.isNotEmpty ? points.first : const LatLng(-17.7833, -63.1821);

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento en tiempo real')),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.engineering, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tecnico?['nombre'] ?? d['tecnico_nombre'] ?? 'Técnico asignado'}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          Text(estadoVisible, style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(icon: Icons.schedule, label: 'Actualización', value: _horaCorta(d['ultima_actualizacion'])),
                    _InfoPill(
                      icon: Icons.route,
                      label: 'Distancia',
                      value: distanciaKm == null ? '-' : '${distanciaKm.toStringAsFixed(distanciaKm < 1 ? 2 : 1)} km',
                    ),
                    _InfoPill(
                      icon: Icons.timer_outlined,
                      label: 'Tiempo estimado',
                      value: etaMin == null ? '-' : '$etaMin min',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    mensajeVisible,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recargar ahora'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
