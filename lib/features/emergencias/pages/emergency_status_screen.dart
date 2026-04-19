import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
      final notificaciones = await _api.getNotifications(incidenteId: _incidenteId);
      if (!mounted) return;
      setState(() {
        _estado = data;
        _mensajes = mensajes;
        _notificaciones = notificaciones;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación enviada')));
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
              value: _incidenteId,
              decoration: const InputDecoration(labelText: 'Solicitud'),
              items: _solicitudes
                  .map((s) {
                    final id = '${s['incidente_id']}';
                    final codigo = (s['codigo_solicitud'] ?? '').toString();
                    final tipo = (s['tipo'] ?? 'incierto').toString();
                    final st = (s['estado'] ?? '').toString();
                    final label = '${codigo.isNotEmpty ? codigo : id.substring(0, 8)} · $tipo · $st';
                    return DropdownMenuItem<String>(value: id, child: Text(label));
                  })
                  .toList(),
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
          Text('Resumen IA: ${_estado?['resumen_ia'] ?? 'Sin resumen disponible'}'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _sendGpsAgain,
            child: const Text('Enviar ubicación GPS nuevamente'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: puedeVerTecnico ? _verUbicacionTecnico : null,
            child: const Text('Ver ubicación del técnico'),
          ),
          if (_tecnicoUbicacion != null) ...[
            const SizedBox(height: 8),
            Text('Técnico: ${_tecnicoUbicacion!['tecnico_nombre'] ?? '-'}'),
            Text('Especialidad: ${_tecnicoUbicacion!['especialidad'] ?? '-'}'),
            Text('Ubicación: ${_tecnicoUbicacion!['lat'] ?? '-'}, ${_tecnicoUbicacion!['lng'] ?? '-'}'),
          ],
          const SizedBox(height: 18),
          const Text('Comunicación', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Mensaje para el taller'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _sending ? null : _enviarMensaje,
            child: Text(_sending ? 'Enviando...' : 'Enviar mensaje'),
          ),
          const SizedBox(height: 8),
          if (_mensajes.isNotEmpty)
            ..._mensajes.map(
              (m) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text((m['texto'] ?? '').toString()),
                subtitle: Text('${m['autor_rol'] ?? ''} · ${m['creado_en'] ?? ''}'),
              ),
            ),
          if (_mensajes.isEmpty) const Text('Sin mensajes para esta solicitud'),
          const SizedBox(height: 16),
          const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (_notificaciones.isNotEmpty)
            ..._notificaciones.map(
              (n) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text((n['titulo'] ?? '').toString()),
                subtitle: Text('${n['mensaje'] ?? ''}\n${n['creada_en'] ?? ''}'),
                isThreeLine: true,
              ),
            ),
          if (_notificaciones.isEmpty) const Text('Sin notificaciones para esta solicitud'),
        ],
      ),
    );
  }
}
