import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../emergencias/services/emergencias_api.dart';
import '../../emergencias/services/emergency_sync_service.dart';
import '../../emergencias/services/offline_emergency_store.dart';

class EmergencyStatusScreen extends StatefulWidget {
  const EmergencyStatusScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<EmergencyStatusScreen> createState() => _EmergencyStatusScreenState();
}

class _EmergencyStatusScreenState extends State<EmergencyStatusScreen>
    with WidgetsBindingObserver {
  final _api = EmergenciesApi();
  final _syncService = EmergencySyncService();
  final _offlineStore = OfflineEmergencyStore();
  final _msgCtrl = TextEditingController();

  Map<String, dynamic>? _estado;
  Map<String, dynamic>? _tecnicoUbicacion;
  List<Map<String, dynamic>> _solicitudes = const [];
  List<OfflineEmergency> _offlinePendientes = const [];
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
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _syncOfflinePending();
      await _cargarSolicitudes();
      await _refresh();
    });
  }

  Future<void> _bootstrap() async {
    await _syncOfflinePending();
    await _cargarSolicitudes();
    await _refresh();
  }

  Future<void> _syncOfflinePending() async {
    try {
      final synced = await _syncService.syncPending();
      if (!mounted || synced <= 0) return;
      await _cargarSolicitudes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$synced emergencia(s) pendiente(s) sincronizada(s).')),
      );
    } catch (_) {
      // La pantalla de estado no debe bloquearse si aún no hay conexión.
    }
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
    if (_isOfflineSelection) return false;
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
        state == 'en_diagnostico' ||
        state == 'diagnostico_completado' ||
        state == 'cotizacion_emitida' ||
        state == 'cotizacion_aceptada' ||
        state == 'en_proceso';
  }

  String _estadoAmigable(String? estado) {
    switch (_stateKey(estado)) {
      case 'pendiente_sincronizacion':
        return 'Pendiente de sincronización';
      case 'sincronizando':
        return 'Sincronizando emergencia';
      case 'error_sincronizacion':
        return 'Error de sincronización';
      case 'conflicto':
        return 'Conflicto de sincronización';
      case 'pendiente':
      case 'pendiente_asignacion':
      case 'pendiente_respuesta':
      case 'pendiente_respuesta_taller':
        return 'Solicitud enviada';
      case 'pendiente_ia':
      case 'procesando_ia':
        return 'Analizando emergencia';
      case 'buscando_taller':
      case 'buscando_talleres':
        return 'Buscando asistencia';
      case 'esperando_respuestas':
        return 'Esperando respuestas';
      case 'esperando_cotizaciones':
        return 'Esperando cotizaciones';
      case 'cotizaciones_recibidas':
        return 'Cotizaciones disponibles';
      case 'taller_confirmado':
      case 'asignada_taller':
      case 'aceptada':
        return 'Taller asignado';
      case 'tecnico_asignado':
        return 'Técnico asignado';
      case 'en_camino':
        return 'Técnico en camino';
      case 'en_diagnostico':
        return 'Técnico en el lugar';
      case 'diagnostico_completado':
        return 'Diagnóstico completado';
      case 'en_proceso':
      case 'atendido':
        return 'En atención';
      case 'cotizacion_emitida':
        return 'Cotización disponible';
      case 'esperando_pago':
      case 'pago_pendiente':
        return 'Pago pendiente';
      case 'pagado':
      case 'servicio_completado':
      case 'finalizado':
      case 'completado':
      case 'completada':
        return 'Servicio completado';
      case 'cancelado':
      case 'cancelada':
      case 'rechazada':
        return 'Solicitud cancelada';
      default:
        return estado ?? 'Sin estado';
    }
  }

  bool get _canRespondQuote {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_responder_cotizacion'] is bool) {
      return actions['puede_responder_cotizacion'] as bool;
    }
    final cotizaciones = _asMapList(_estado?['cotizaciones_disponibles']);
    if (cotizaciones.isNotEmpty) {
      return cotizaciones.any((c) {
        final est = (c['estado'] ?? '').toString().toLowerCase();
        return est == 'emitida' || est == 'pendiente' || est == 'enviada';
      });
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

  bool get _isOfflineSelection => _incidenteId.startsWith('OFF-EMG-');

  Map<String, dynamic> _offlineToSolicitud(OfflineEmergency row) {
    final tipo = row.descripcion.trim().isEmpty ? 'emergencia' : 'emergencia';
    return {
      'incidente_id': row.offlineSyncId,
      'codigo_visible': row.offlineSyncId,
      'fecha_reporte': row.fechaLocal,
      'estado': row.estadoSync,
      'tipo': tipo,
      'tipo_cliente': tipo,
      'vehiculo': {'placa': 'Pendiente'},
      'offline': true,
    };
  }

  Map<String, dynamic> _offlineToEstado(OfflineEmergency row) {
    return {
      'id': row.offlineSyncId,
      'estado': row.estadoSync,
      'tipo': row.descripcion.trim().isEmpty ? 'emergencia' : 'emergencia',
      'prioridad': '-',
      'resumen_ia':
          'La emergencia está guardada en el dispositivo. La IA se procesará cuando se sincronice con el servidor.',
      'ubicacion': {
        'latitud': row.lat,
        'longitud': row.lng,
      },
      'historial': [
        {
          'estado_nuevo': row.estadoSync,
          'creado_en': row.fechaLocal,
        }
      ],
      'acciones_disponibles': {
        'puede_cancelar': false,
        'puede_ver_tecnico': false,
        'puede_pagar': false,
        'puede_evaluar_servicio': false,
      },
      'offline_sync_id': row.offlineSyncId,
      'error_sync': row.error,
    };
  }

  Future<List<Map<String, dynamic>>> _loadOfflineSolicitudes() async {
    final rows = await _offlineStore.list();
    final pending = rows.where((e) => e.estadoSync != 'sincronizado').toList();
    _offlinePendientes = pending;
    return pending.map(_offlineToSolicitud).toList();
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
      final offlineRows = await _loadOfflineSolicitudes();
      final rows = await _api.getTrackRequests();
      if (!mounted) return;
      setState(() {
        _solicitudes = [...offlineRows, ...rows];
        _error = '';
        final currentExists =
            _solicitudes.any((s) => '${s['incidente_id']}' == _incidenteId);
        if ((_incidenteId.isEmpty || !currentExists) && _solicitudes.isNotEmpty) {
          _incidenteId = '${_solicitudes.first['incidente_id']}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      final offlineRows = await _loadOfflineSolicitudes();
      if (!mounted) return;
      setState(() {
        _solicitudes = offlineRows;
        final currentExists =
            offlineRows.any((s) => '${s['incidente_id']}' == _incidenteId);
        if ((_incidenteId.isEmpty || !currentExists) && offlineRows.isNotEmpty) {
          _incidenteId = '${offlineRows.first['incidente_id']}';
        }
        _error = offlineRows.isEmpty
            ? 'No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.'
            : '';
      });
    } finally {
      if (mounted) setState(() => _loadingSolicitudes = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _incidenteId.isEmpty) return;
    if (_isOfflineSelection) {
      final local = _offlinePendientes
          .where((e) => e.offlineSyncId == _incidenteId)
          .toList();
      if (local.isNotEmpty && mounted) {
        setState(() {
          _estado = _offlineToEstado(local.first);
          _tecnicoUbicacion = null;
          _error = '';
        });
      }
      return;
    }
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
    } catch (_) {
      if (!mounted) return;
      final offlineRows = await _loadOfflineSolicitudes();
      if (!mounted) return;
      if (offlineRows.isNotEmpty) {
        final currentExists =
            offlineRows.any((s) => '${s['incidente_id']}' == _incidenteId);
        final selectedId = currentExists
            ? _incidenteId
            : '${offlineRows.first['incidente_id']}';
        final local = _offlinePendientes
            .where((e) => e.offlineSyncId == selectedId)
            .toList();
        setState(() {
          _solicitudes = offlineRows;
          _incidenteId = selectedId;
          _estado = local.isNotEmpty ? _offlineToEstado(local.first) : _estado;
          _tecnicoUbicacion = null;
          _error = '';
        });
        return;
      }
      setState(
        () => _error =
            'No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.',
      );
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
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

  Future<void> _abrirCotizaciones() async {
    if (_incidenteId.isEmpty || _isOfflineSelection) return;
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.cotizacionesComparar,
      arguments: _incidenteId,
    );
    if (!mounted) return;
    if (updated == true) {
      await _refresh();
      await _cargarSolicitudes();
    } else {
      await _refresh();
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
        title: const Text('Procesar pago'),
        content: StatefulBuilder(
          builder: (context, setLocalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: metodo,
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
        title: const Text('Evaluar servicio'),
        content: StatefulBuilder(
          builder: (context, setLocalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: calificacion,
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
      _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _syncOfflinePending();
        await _cargarSolicitudes();
        await _refresh();
      });
      unawaited(_bootstrap());
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
    final cotizacionesDisponibles = _asMapList(_estado?['cotizaciones_disponibles']);
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
                    isExpanded: true,
                    initialValue: selectedValue,
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
                          StatusChip(status: _estadoAmigable(estado)),
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
                    StatusChip(status: _estadoAmigable(estado)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _estadoAmigable(estado),
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                if (cotizacionesDisponibles.isNotEmpty ||
                    (cotizacion != null && _canRespondQuote)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cotizacionesDisponibles.length > 1
                              ? '${cotizacionesDisponibles.length} cotizaciones recibidas'
                              : 'Cotización disponible',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compara precio, tiempo y detalle de cada taller en una pantalla dedicada.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _abrirCotizaciones,
                            icon: const Icon(Icons.compare_arrows),
                            label: const Text('Ver cotizaciones'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (pago != null) ...[
                  Text('Pago: ${pago['estado'] ?? '-'}'),
                  if (pago['monto'] != null) Text('Monto total: ${pago['monto']}'),
                  if (pago['comision_plataforma'] != null)
                    Text('Comisión plataforma (10%): ${pago['comision_plataforma']}'),
                  if (pago['monto_taller'] != null)
                    Text('Monto neto taller: ${pago['monto_taller']}'),
                ],
                if (_canPay && !_isFinalState) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _procesarPago,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Procesar pago'),
                  ),
                ],
                if (_canEvaluate) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _evaluarServicio,
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Evaluar servicio'),
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
              title: 'Historial del servicio',
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Ver historial de cambios'),
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
              title: 'Ubicación del técnico',
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
