import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../services/emergencias_api.dart';

class EmergencyStatusScreen extends StatefulWidget {
  const EmergencyStatusScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<EmergencyStatusScreen> createState() => _EmergencyStatusScreenState();
}

class _EmergencyStatusScreenState extends State<EmergencyStatusScreen>
    with WidgetsBindingObserver {
  final _api = EmergenciesApi();
  final _msgCtrl = TextEditingController();

  Map<String, dynamic>? _estado;
  Map<String, dynamic>? _tecnicoUbicacion;
  List<Map<String, dynamic>> _solicitudes = const [];
  String _incidenteId = '';
  String _error = '';
  bool _refreshing = false;
  bool _loadingSolicitudes = false;
  bool _sending = false;
  Timer? _timer;

  static const _cancelableStates = {
    'pendiente',
    'buscando_taller',
    'pendiente_asignacion',
    'asignado',
    'pendiente_respuesta',
    'pendiente_respuesta_taller',
    'aceptada',
    'tecnico_asignado',
    'en_camino',
  };

  static const _finalStates = {
    'cancelada',
    'cancelado',
    'rechazada',
    'completada',
    'completado',
    'finalizado',
    'pagado',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incidenteId = widget.incidenteId.trim();
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  Future<void> _bootstrap() async {
    await _cargarSolicitudes();
    await _refresh();
  }

  String _stateKey(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(' ', '_');

  bool get _isFinalState =>
      _finalStates.contains(_stateKey('${_estado?['estado'] ?? ''}'));

  bool get _canCancel {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_cancelar'] is bool) {
      return actions['puede_cancelar'] as bool;
    }
    return _cancelableStates.contains(_stateKey('${_estado?['estado'] ?? ''}'));
  }

  bool get _canViewTechnician {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_ver_tecnico'] is bool) {
      return actions['puede_ver_tecnico'] as bool;
    }
    final state = _stateKey('${_estado?['estado'] ?? ''}');
    return state == 'tecnico_asignado' ||
        state == 'en_camino' ||
        state == 'en_proceso';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      final map = _asMap(item);
      if (map != null) out.add(map);
    }
    return out;
  }

  String _formatFechaCorta(String? iso) {
    if ((iso ?? '').trim().isEmpty) return 'Sin fecha';
    final parsed = DateTime.tryParse(iso!);
    if (parsed == null) return 'Sin fecha';
    final now = DateTime.now();
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return 'Hoy $hh:$mm';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _labelSolicitudCorto(Map<String, dynamic> s) {
    final tipo = (s['tipo_cliente'] ??
            s['tipo_reportado'] ??
            s['tipo'] ??
            s['tipo_problema'] ??
            'incidente')
        .toString();
    final fecha = _formatFechaCorta(s['fecha_reporte']?.toString());
    final vehiculo = _asMap(s['vehiculo']);
    final placa = (vehiculo?['placa'] ?? '').toString();
    final vehiculoTxt = placa.isNotEmpty ? placa : 'Vehículo';
    return '$fecha · $vehiculoTxt · $tipo';
  }

  String _tipoClientePreferido() {
    final current =
        _solicitudes.where((e) => '${e['incidente_id']}' == _incidenteId);
    if (current.isNotEmpty) {
      final s = current.first;
      final fromCliente =
          (s['tipo_cliente'] ?? s['tipo_reportado'] ?? s['tipo'])
              .toString()
              .trim();
      if (fromCliente.isNotEmpty) return fromCliente;
    }
    final fallback = (_estado?['tipo'] ?? _estado?['tipo_problema'] ?? '-')
        .toString()
        .trim();
    return fallback.isEmpty ? '-' : fallback;
  }

  Future<void> _cargarSolicitudes() async {
    setState(() => _loadingSolicitudes = true);
    try {
      final rows = await _api.getTrackRequests();
      if (!mounted) return;
      setState(() {
        _solicitudes = rows;
        _error = '';
        if (_incidenteId.isEmpty && rows.isNotEmpty) {
          _incidenteId = '${rows.first['incidente_id']}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingSolicitudes = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _incidenteId.isEmpty) return;
    _refreshing = true;
    try {
      final data = await _api.getEmergencyStatus(_incidenteId);
      if (!mounted) return;
      setState(() {
        _estado = data;
        _error = '';
      });

      if (_canViewTechnician) {
        try {
          final tech = await _api.getTechnicianLocation(_incidenteId);
          if (!mounted) return;
          setState(() => _tecnicoUbicacion = tech);
        } catch (_) {}
      } else {
        if (!mounted) return;
        setState(() => _tecnicoUbicacion = null);
      }

      if (_isFinalState) {
        _timer?.cancel();
        _timer = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _cancelarSolicitud() async {
    if (!_canCancel) return;
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: TextField(
          controller: motivoCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.cancelEmergency(_incidenteId, motivo: motivoCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada correctamente')),
      );
      await _refresh();
      await _cargarSolicitudes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _sendGpsAgain() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await _api.sendGps(
        incidenteId: _incidenteId,
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _sendMessage() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty || _incidenteId.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.sendMessage(_incidenteId, txt);
      if (!mounted) return;
      _msgCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (state == AppLifecycleState.resumed && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = '${_estado?['estado'] ?? 'sin_datos'}';
    final historial = _asMapList(_estado?['historial']);
    final taller = _asMap(_estado?['taller_asignado']);
    final tecnico = _asMap(_estado?['tecnico_asignado']);
    final cotizacion = _asMap(_estado?['cotizacion_actual']);
    final pago = _asMap(_estado?['pago_actual']);
    final ubicacion = _asMap(_estado?['ubicacion']);

    final selectedExists =
        _solicitudes.any((s) => '${s['incidente_id']}' == _incidenteId);
    final selectedValue = selectedExists ? _incidenteId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CU13 · Estado de solicitud'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              return;
            }
            await Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (_) => false);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Solicitudes',
            subtitle: 'Selecciona una solicitud para ver su estado.',
            child: Column(
              children: [
                if (_loadingSolicitudes)
                  const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 8),
                if (_solicitudes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedValue,
                    decoration: const InputDecoration(labelText: 'Solicitud'),
                    items: _solicitudes.map((s) {
                      final id = '${s['incidente_id']}';
                      final label = _labelSolicitudCorto(s);
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null || value.isEmpty) return;
                      setState(() => _incidenteId = value);
                      _refresh();
                    },
                  )
                else
                  const Text('No hay solicitudes disponibles.'),
                const SizedBox(height: 8),
                if (selectedValue != null)
                  Builder(
                    builder: (_) {
                      final current = _solicitudes.firstWhere(
                        (e) => '${e['incidente_id']}' == selectedValue,
                        orElse: () => const {},
                      );
                      if (current.isEmpty) return const SizedBox.shrink();
                      final estado = (current['estado'] ?? '').toString();
                      return Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Solicitud seleccionada',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                          StatusChip(status: estado),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _refreshing ? null : _cargarSolicitudes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recargar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_refreshing && _estado == null) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Estado actual',
            subtitle: 'CU12 disponible según estado de la solicitud.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Estado: '),
                    StatusChip(status: estado),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tipo: ${_tipoClientePreferido()}'),
                Text('Prioridad: ${_estado?['prioridad'] ?? '-'}'),
                Text('Resumen IA: ${_estado?['resumen_ia'] ?? '-'}'),
                Text(
                    'Taller: ${_estado?['taller_nombre'] ?? taller?['nombre'] ?? '-'}'),
                Text(
                    'Técnico: ${_estado?['tecnico_nombre'] ?? tecnico?['nombre'] ?? '-'}'),
                if (ubicacion != null)
                  Text(
                      'Ubicación enviada: ${ubicacion['latitud'] ?? '-'}, ${ubicacion['longitud'] ?? '-'}'),
                if (cotizacion != null)
                  Text(
                      'Cotización: ${cotizacion['monto'] ?? '-'} (${cotizacion['estado'] ?? '-'})'),
                if (pago != null) Text('Pago: ${pago['estado'] ?? '-'}'),
                const SizedBox(height: 10),
                if (_canCancel)
                  ElevatedButton.icon(
                    onPressed: _cancelarSolicitud,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger),
                    icon: const Icon(Icons.cancel),
                    label: const Text('CU12 · Cancelar solicitud'),
                  )
                else
                  const Text(
                    'No se puede cancelar en este estado.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          if (historial.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Línea de tiempo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: historial
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '• ${h['estado_nuevo'] ?? '-'}'
                          '${(h['creado_en'] ?? '').toString().isNotEmpty ? ' (${h['creado_en']})' : ''}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (_tecnicoUbicacion != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'CU19 · Ubicación del técnico',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Técnico: ${_tecnicoUbicacion!['tecnico_nombre'] ?? '-'}'),
                  Text(
                      'Especialidad: ${_tecnicoUbicacion!['especialidad'] ?? '-'}'),
                  Text('Lat: ${_tecnicoUbicacion!['lat'] ?? '-'}'),
                  Text('Lng: ${_tecnicoUbicacion!['lng'] ?? '-'}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Acciones rápidas',
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: _sendGpsAgain,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Enviar ubicación nuevamente'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Mensaje para el taller'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: Text(_sending ? 'Enviando...' : 'Enviar mensaje'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.emergenciaReport),
                  icon: const Icon(Icons.add_alert),
                  label: const Text('Reportar nueva emergencia'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
