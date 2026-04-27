import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../emergencias/services/emergencias_api.dart';

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
  StreamSubscription<Position>? _gpsSubscription;
  DateTime? _lastGpsSentAt;
  bool _trackingActivo = false;
  String _trackingMensaje = 'Seguimiento GPS inactivo';

  static const _cancelableStates = {
    'pendiente',
    'buscando_taller',
    'pendiente_asignacion',
    'en_revision',
    'en_evaluacion',
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

  bool get _canRespondQuote {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_responder_cotizacion'] is bool) {
      return actions['puede_responder_cotizacion'] as bool;
    }
    final cot = _asMap(_estado?['cotizacion_actual']);
    final est = (cot?['estado'] ?? '').toString().toLowerCase();
    return est == 'emitida' || est == 'pendiente' || est == 'enviada';
  }

  bool get _canPay {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_pagar'] is bool) {
      return actions['puede_pagar'] as bool;
    }
    return false;
  }

  bool get _canEvaluate {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_evaluar_servicio'] is bool) {
      return actions['puede_evaluar_servicio'] as bool;
    }
    return false;
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
      unawaited(_sincronizarTrackingCliente());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _sincronizarTrackingCliente() async {
    if (_incidenteId.isEmpty || _isFinalState) {
      await _detenerTrackingCliente('Seguimiento GPS detenido');
      return;
    }
    if (_gpsSubscription != null) return;
    await _iniciarTrackingCliente();
  }

  Future<void> _iniciarTrackingCliente() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() {
          _trackingActivo = false;
          _trackingMensaje = 'Activa el GPS para compartir ubicación en tiempo real';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _trackingActivo = false;
          _trackingMensaje = 'Permiso de ubicación denegado';
        });
        return;
      }

      final settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      _gpsSubscription = Geolocator.getPositionStream(locationSettings: settings)
          .listen((pos) {
        unawaited(_enviarGpsTracking(pos));
      });

      // Envía inmediatamente al iniciar el seguimiento.
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await _enviarGpsTracking(first, force: true);
      if (!mounted) return;
      setState(() {
        _trackingActivo = true;
        _trackingMensaje = 'Compartiendo ubicación en tiempo real';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trackingActivo = false;
        _trackingMensaje = 'No se pudo iniciar el seguimiento GPS';
      });
    }
  }

  Future<void> _detenerTrackingCliente([String? mensaje]) async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    if (!mounted) return;
    setState(() {
      _trackingActivo = false;
      _trackingMensaje = mensaje ?? 'Seguimiento GPS inactivo';
    });
  }

  Future<void> _enviarGpsTracking(Position pos, {bool force = false}) async {
    if (_incidenteId.isEmpty) return;
    final now = DateTime.now();
    if (!force &&
        _lastGpsSentAt != null &&
        now.difference(_lastGpsSentAt!).inSeconds < 10) {
      return;
    }
    try {
      await _api.sendGps(
        incidenteId: _incidenteId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _lastGpsSentAt = now;
      if (!mounted) return;
      setState(() {
        _trackingActivo = true;
        _trackingMensaje =
            'Ubicación actualizada ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trackingActivo = false;
        _trackingMensaje = 'No se pudo enviar ubicación en este momento';
      });
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

  Future<void> _responderCotizacion(bool aceptar) async {
    final cot = _asMap(_estado?['cotizacion_actual']);
    final cotId = (cot?['id'] ?? '').toString().trim();
    if (cotId.isEmpty) return;

    final obsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aceptar ? 'Aceptar cotización' : 'Rechazar cotización'),
        content: TextField(
          controller: obsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: !aceptar
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(aceptar ? 'Aceptar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (aceptar) {
        await _api.acceptQuote(cotId, observaciones: obsCtrl.text.trim());
      } else {
        await _api.rejectQuote(cotId, observaciones: obsCtrl.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aceptar ? 'Cotización aceptada correctamente' : 'Cotización rechazada correctamente',
          ),
        ),
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

  Future<void> _procesarPago() async {
    final cot = _asMap(_estado?['cotizacion_actual']);
    final cotId = (cot?['id'] ?? '').toString().trim();
    if (cotId.isEmpty) return;
    String metodo = 'qr';
    final referenciaCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CU22 · Procesar pago'),
        content: StatefulBuilder(
          builder: (context, setLocalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: metodo,
                items: const [
                  DropdownMenuItem(value: 'qr', child: Text('QR')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                ],
                onChanged: (v) => setLocalState(() => metodo = (v ?? 'qr')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: referenciaCtrl,
                decoration: const InputDecoration(labelText: 'Referencia (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar pago')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.processPayment(
        cotizacionId: cotId,
        metodoPago: metodo,
        referencia: referenciaCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago procesado correctamente')),
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

  Future<void> _evaluarServicio() async {
    int calificacion = 5;
    final comentarioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CU24 · Evaluar servicio'),
        content: StatefulBuilder(
          builder: (context, setLocalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: calificacion,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 estrella')),
                  DropdownMenuItem(value: 2, child: Text('2 estrellas')),
                  DropdownMenuItem(value: 3, child: Text('3 estrellas')),
                  DropdownMenuItem(value: 4, child: Text('4 estrellas')),
                  DropdownMenuItem(value: 5, child: Text('5 estrellas')),
                ],
                onChanged: (v) => setLocalState(() => calificacion = v ?? 5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: comentarioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar evaluación')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.evaluateService(
        incidenteId: _incidenteId,
        calificacion: calificacion,
        comentario: comentarioCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluación registrada')),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
      unawaited(_detenerTrackingCliente('Seguimiento pausado'));
      return;
    }
    if (state == AppLifecycleState.resumed && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _gpsSubscription?.cancel();
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
        title: const Text('Estado de solicitud'),
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
            subtitle: 'disponible según estado de la solicitud.',
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
                if (ubicacion != null) const Text('Ubicación de emergencia registrada'),
                if (cotizacion != null)
                  Text(
                      'Cotización: ${cotizacion['monto'] ?? '-'} (${cotizacion['estado'] ?? '-'})'),
                if (pago != null) Text('Pago: ${pago['estado'] ?? '-'}'),
                if (cotizacion != null &&
                    _canRespondQuote &&
                    !_isFinalState) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _responderCotizacion(true),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Aceptar cotización'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _responderCotizacion(false),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Rechazar cotización'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_canPay && !_isFinalState) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _procesarPago,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('CU22 · Procesar pago'),
                  ),
                ],
                if (_canEvaluate) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _evaluarServicio,
                    icon: const Icon(Icons.star_outline),
                    label: const Text('CU24 · Evaluar servicio'),
                  ),
                ],
                const SizedBox(height: 10),
                if (_canCancel)
                  ElevatedButton.icon(
                    onPressed: _cancelarSolicitud,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar solicitud'),
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
                  Text('Estado: ${_tecnicoUbicacion!['estado_servicio'] ?? '-'}'),
                  Text('Última actualización: ${_tecnicoUbicacion!['ultima_actualizacion'] ?? '-'}'),
                  if ((_tecnicoUbicacion!['mensaje'] ?? '').toString().trim().isNotEmpty)
                    Text(
                      '${_tecnicoUbicacion!['mensaje']}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.tecnicoLocation,
                      arguments: _incidenteId,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver ubicación del técnico'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Acciones rápidas',
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _trackingActivo ? Icons.gps_fixed : Icons.gps_off,
                      color: _trackingActivo ? Colors.green : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _trackingMensaje,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
