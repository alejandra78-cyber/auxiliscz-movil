import 'dart:async';

import 'live_tracking_map_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/emergencias_api.dart';

class EmergencyStatusScreen extends StatefulWidget {
  const EmergencyStatusScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<EmergencyStatusScreen> createState() => _EmergencyStatusScreenState();
}

class _EmergencyStatusScreenState extends State<EmergencyStatusScreen> {
  final _api = EmergenciesApi();
  final _msgCtrl = TextEditingController();

  Map<String, dynamic>? _estado;
  Map<String, dynamic>? _tecnicoUbicacion;
  List<Map<String, dynamic>> _solicitudes = const [];
  List<Map<String, dynamic>> _mensajes = const [];
  List<Map<String, dynamic>> _notificaciones = const [];
  Timer? _timer;

  late String _incidenteId;
  late DateTime _fechaReferencia;
  bool _sending = false;
  bool _loadingSolicitudes = true;

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _incidenteId = widget.incidenteId;
    _fechaReferencia = DateTime.now();
    _cargarSolicitudes();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  String get _codigoReferencia {
    final codeFromApi = _estado?['codigo_solicitud']?.toString();
    if (codeFromApi != null && codeFromApi.isNotEmpty) return codeFromApi;
    final id = _incidenteId;
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  String get _fechaHoraTexto {
    final d = _fechaReferencia;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  Future<void> _cargarSolicitudes() async {
    setState(() => _loadingSolicitudes = true);
    try {
      final rows = await _api.getTrackRequests();
      if (!mounted) return;
      setState(() {
        _solicitudes = rows;
        final exists = rows.any((e) => '${e['incidente_id']}' == _incidenteId);
        if (!exists && rows.isNotEmpty) {
          _incidenteId = '${rows.first['incidente_id']}';
        }
      });
    } catch (_) {
      // mantenemos fallback con incidente actual
    } finally {
      if (mounted) setState(() => _loadingSolicitudes = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.getEmergencyStatus(_incidenteId);
      final mensajes = await _api.getMessages(_incidenteId);
      final notificaciones =
          await _api.getNotifications(incidenteId: _incidenteId);
      final estado = '${data['estado'] ?? ''}';
      Map<String, dynamic>? tecnico;
      if (estado == 'asignada' || estado == 'en_proceso') {
        try {
          tecnico = await _api.getTechnicianLocation(_incidenteId);
        } catch (_) {
          tecnico = _tecnicoUbicacion;
        }
      } else {
        tecnico = null;
      }
      if (!mounted) return;
      setState(() {
        _estado = data;
        _mensajes = mensajes;
        _notificaciones = notificaciones;
        _tecnicoUbicacion = tecnico;
      });
    } catch (_) {}
  }

  Future<void> _sendGpsAgain() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      await _api.sendGps(
        incidenteId: _incidenteId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación enviada')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _verUbicacionTecnico() async {
    try {
      final data = await _api.getTechnicianLocation(_incidenteId);
      if (!mounted) return;
      setState(() => _tecnicoUbicacion = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['mensaje'] ?? 'Ubicación procesada'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.sendMessage(_incidenteId, texto);
      _msgCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = '${_estado?['estado'] ?? 'consultando...'}';
    final puedeVerTecnico = estado == 'asignada' || estado == 'en_proceso';

    return Scaffold(
      appBar: AppBar(title: const Text('Consultar Estado de solicitud')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadingSolicitudes)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_solicitudes.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _incidenteId,
              decoration: const InputDecoration(labelText: 'Solicitud'),
              items: _solicitudes.map((s) {
                final id = '${s['incidente_id']}';
                final codigo = (s['codigo_solicitud'] ?? '').toString();
                final tipo = (s['tipo'] ?? 'incierto').toString();
                final st = (s['estado'] ?? '').toString();
                final label =
                    '${codigo.isNotEmpty ? codigo : id.substring(0, 8)} · $tipo · $st';
                return DropdownMenuItem<String>(value: id, child: Text(label));
              }).toList(),
              onChanged: (value) {
                if (value == null || value.isEmpty) return;
                setState(() {
                  _incidenteId = value;
                  _tecnicoUbicacion = null;
                });
                _refresh();
              },
            ),
          const SizedBox(height: 12),
          Text('Referencia: $_codigoReferencia'),
          const SizedBox(height: 8),
          Text('Fecha y hora: $_fechaHoraTexto'),
          const SizedBox(height: 8),
          Text('Estado: $estado'),
          const SizedBox(height: 8),
          Text('Tipo: ${_estado?['tipo'] ?? '-'}'),
          const SizedBox(height: 8),
          Text('Prioridad: ${_estado?['prioridad'] ?? '-'}'),
          const SizedBox(height: 8),
          Text('Taller asignado: ${_estado?['taller_nombre'] ?? '-'}'),
          const SizedBox(height: 8),
          Text(
              'Resumen IA: ${_estado?['resumen_ia'] ?? 'Sin resumen disponible'}'),
          const SizedBox(height: 12),
          Text('Taller asignado: ${_estado?['taller_nombre'] ?? '-'}'),
          const SizedBox(height: 8),
          Text(
            'Tiempo estimado de llegada: ${_estado?['tiempo_estimado_min'] ?? '-'} min',
          ),
          ElevatedButton(
            onPressed: _sendGpsAgain,
            child: const Text('Enviar ubicación GPS nuevamente'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: puedeVerTecnico ? _verUbicacionTecnico : null,
            child: const Text('Ver ubicación del técnico'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _tecnicoUbicacion == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveTrackingMapScreen(
                          incidenteId: _incidenteId,
                          clienteLat: _toDouble(_estado?['lat']) ?? -17.7833,
                          clienteLng: _toDouble(_estado?['lng']) ?? -63.1821,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.map),
            label: const Text('Ver técnico en mapa (tiempo real)'),
          ),
          if (_tecnicoUbicacion != null) ...[
            const SizedBox(height: 8),
            Text('Técnico: ${_tecnicoUbicacion!['tecnico_nombre'] ?? '-'}'),
            Text('Especialidad: ${_tecnicoUbicacion!['especialidad'] ?? '-'}'),
            Text(
                'Ubicación: ${_tecnicoUbicacion!['lat'] ?? '-'}, ${_tecnicoUbicacion!['lng'] ?? '-'}'),
            if (_toDouble(_tecnicoUbicacion!['lat']) != null &&
                _toDouble(_tecnicoUbicacion!['lng']) != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 230,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      _toDouble(_tecnicoUbicacion!['lat'])!,
                      _toDouble(_tecnicoUbicacion!['lng'])!,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.auxilioscz.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 44,
                          height: 44,
                          point: LatLng(
                            _toDouble(_tecnicoUbicacion!['lat'])!,
                            _toDouble(_tecnicoUbicacion!['lng'])!,
                          ),
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          const Text('Comunicación',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8EDF8)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat de la solicitud',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_mensajes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aún no hay mensajes para esta solicitud'),
                  ),
                if (_mensajes.isNotEmpty)
                  ..._mensajes.map((m) {
                    final role =
                        ((m['autor_rol'] ?? '').toString()).toLowerCase();
                    final outgoing = role == 'conductor' || role == 'cliente';
                    return Align(
                      alignment: outgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: outgoing
                              ? const Color(0xFF1F3A7A)
                              : const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: outgoing
                                ? const Color(0xFF1F3A7A)
                                : const Color(0xFFD8E3FF),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m['autor_rol'] ?? ''} · ${m['creado_en'] ?? ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: outgoing
                                    ? const Color(0xFFDCE6FF)
                                    : const Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (m['texto'] ?? '').toString(),
                              style: TextStyle(
                                  color: outgoing
                                      ? Colors.white
                                      : const Color(0xFF101828)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mensaje para el taller',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sending ? null : _enviarMensaje,
                      child: Text(_sending ? 'Enviando...' : 'Enviar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Notificaciones',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (_notificaciones.isEmpty)
            const Text('Sin notificaciones para esta solicitud'),
          if (_notificaciones.isNotEmpty)
            ..._notificaciones.map(
              (n) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE8EDF8)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((n['titulo'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text((n['mensaje'] ?? '').toString()),
                    const SizedBox(height: 4),
                    Text(
                      '${n['tipo'] ?? ''} · ${n['estado'] ?? ''} · ${n['creada_en'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
