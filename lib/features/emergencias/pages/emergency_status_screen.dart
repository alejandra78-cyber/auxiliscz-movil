import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geolocator/geolocator.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../services/emergency_sync_service.dart';
import '../services/emergencias_api.dart';
import '../services/offline_emergency_store.dart';

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

  Map<String, dynamic>? _estado;
  Map<String, dynamic>? _tecnicoUbicacion;
  List<Map<String, dynamic>> _solicitudes = const [];
  String _incidenteId = '';
  String _error = '';
  bool _refreshing = false;
  bool _loadingSolicitudes = false;
  bool _syncingOffline = false;
  bool _paymentSheetActive = false;
  Timer? _timer;

  static const _cancelableStates = {
    'pendiente',
    'buscando_taller',
    'pendiente_asignacion',
    'asignado',
    'pendiente_respuesta',
    'pendiente_respuesta_taller',
    'aceptada',
    'taller_confirmado',
    'confirmada',
    'cotizacion_aceptada',
    'tecnico_asignado',
    'en_camino',
    'tecnico_en_lugar',
    'en_diagnostico',
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
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    if (_timer != null || _paymentSheetActive) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_paymentSheetActive) return;
      await _syncOfflineIfNeeded();
      await _refresh();
    });
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _bootstrap() async {
    await _syncOfflineIfNeeded(showMessage: true);
    await _cargarSolicitudes();
    await _refresh();
  }

  Future<void> _syncOfflineIfNeeded({bool showMessage = false}) async {
    if (_syncingOffline) return;
    _syncingOffline = true;
    final synced = await _syncService.syncPending().whenComplete(() {
      _syncingOffline = false;
    });
    if (!mounted || synced <= 0) return;
    await _cargarSolicitudes();
    if (!mounted) return;
    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$synced emergencia(s) offline sincronizada(s)')),
      );
    }
  }

  String _stateKey(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(' ', '_');

  bool get _isFinalState =>
      _finalStates.contains(_stateKey('${_estado?['estado'] ?? ''}'));

  bool get _isOfflineSelection => _incidenteId.startsWith('OFF-EMG-');

  bool get _canCancel {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_cancelar'] is bool) {
      return actions['puede_cancelar'] as bool;
    }
    return _cancelableStates.contains(_stateKey('${_estado?['estado'] ?? ''}'));
  }

  bool get _canViewTechnician {
    final state = _stateKey('${_estado?['estado'] ?? ''}');
    if ({
      'trabajo_completado',
      'esperando_pago',
      'finalizado',
      'pagado',
      'servicio_completado',
      'completado',
      'completada',
      'cancelado',
      'cancelada',
      'rechazada',
    }.contains(state)) {
      return false;
    }
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_ver_tecnico'] is bool) {
      return actions['puede_ver_tecnico'] as bool;
    }
    return state == 'tecnico_asignado' ||
        state == 'en_camino' ||
        state == 'tecnico_en_lugar' ||
        state == 'en_diagnostico' ||
        state == 'diagnostico_completado' ||
        state == 'cotizacion_emitida' ||
        state == 'cotizacion_aceptada' ||
        state == 'en_proceso';
  }

  bool get _canOpenTechnicianTracking {
    if (_isOfflineSelection || _incidenteId.isEmpty) return false;
    return _canViewTechnician || _tecnicoUbicacion != null;
  }

  String _estadoAmigable(String? estado) {
    switch (_stateKey(estado)) {
      case 'pendiente':
      case 'pendiente_asignacion':
      case 'pendiente_respuesta':
      case 'pendiente_respuesta_taller':
        return 'Solicitud enviada';
      case 'pendiente_sincronizacion':
        return 'Pendiente sin conexión';
      case 'sincronizando':
        return 'Sincronizando';
      case 'error_sincronizacion':
        return 'Error de sincronización';
      case 'pendiente_ia':
      case 'procesando_ia':
        return 'Analizando emergencia';
      case 'buscando_taller':
        return 'Buscando asistencia';
      case 'esperando_cotizaciones':
        return 'Esperando cotizaciones';
      case 'cotizaciones_recibidas':
        return 'Cotizaciones recibidas';
      case 'enviada':
      case 'emitida':
        return 'Cotización recibida';
      case 'taller_confirmado':
      case 'asignada':
      case 'asignada_taller':
      case 'aceptada':
        return 'Taller asignado';
      case 'tecnico_asignado':
        return 'Técnico asignado';
      case 'en_camino':
        return 'Técnico en camino';
      case 'en_diagnostico':
      case 'tecnico_en_lugar':
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
      case 'trabajo_completado':
        return 'Trabajo completado';
      case 'cancelado':
      case 'cancelada':
      case 'rechazada':
        return 'Solicitud cancelada';
      case 'cancelado_con_cobro':
        return 'Pago por visita pendiente';
      default:
        return estado ?? 'Sin estado';
    }
  }

  bool get _canRespondQuote {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_responder_cotizacion'] is bool) {
      final suggested = actions['puede_responder_cotizacion'] as bool;
      if (suggested) return true;
    }
    return _cotizacionesParaCliente.any(_cotizacionPendiente);
  }

  List<Map<String, dynamic>> get _cotizacionesParaCliente {
    final rows = [
      ..._asMapList(_estado?['cotizaciones_disponibles']),
    ];
    final cot = _asMap(_estado?['cotizacion_actual']);
    if (cot != null) rows.add(cot);

    final byTaller = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final estado = _stateKey(row['estado']?.toString());
      if (!{
        'pendiente',
        'emitida',
        'enviada',
        'cotizacion_enviada',
        'aceptada',
      }.contains(estado)) {
        continue;
      }
      final key = (row['taller_id'] ?? row['taller_nombre'] ?? row['id'] ?? '')
          .toString();
      if (key.isEmpty) continue;
      final current = byTaller[key];
      if (current == null ||
          _stateKey(current['estado']?.toString()) != 'aceptada' &&
              estado == 'aceptada') {
        byTaller[key] = row;
      }
    }
    return byTaller.values.toList();
  }

  bool _cotizacionPendiente(Map<String, dynamic> cotizacion) {
    final est = (cotizacion['estado'] ?? '').toString().trim().toLowerCase();
    return est == 'emitida' ||
        est == 'pendiente' ||
        est == 'enviada' ||
        est == 'cotizacion_enviada';
  }

  Future<void> _abrirComparacionCotizaciones() async {
    if (_incidenteId.isEmpty || _isOfflineSelection) return;
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.cotizacionesComparar,
      arguments: _incidenteId,
    );
    if (!mounted) return;
    if (changed == true) {
      await _refresh();
      await _cargarSolicitudes();
    } else {
      await _refresh();
    }
  }

  bool get _canPay {
    final actions = _asMap(_estado?['acciones_disponibles']);
    if (actions != null && actions['puede_pagar'] is bool) {
      final suggested = actions['puede_pagar'] as bool;
      if (!suggested) return false;
      final pago = _asMap(_estado?['pago_actual']);
      final estadoPago = (pago?['estado'] ?? '').toString().trim().toLowerCase();
      if (estadoPago == 'completado' || estadoPago == 'pagado') {
        return false;
      }
      return true;
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

  Map<String, dynamic> _offlineToSolicitud(OfflineEmergency row) {
    return {
      'incidente_id': row.offlineSyncId,
      'codigo_solicitud': row.offlineSyncId,
      'estado': row.estadoSync,
      'tipo': 'emergencia offline',
      'fecha_reporte': row.fechaLocal,
      'vehiculo': {
        'placa': 'Pendiente',
        'id': row.vehiculoId,
      },
      'acciones_disponibles': {
        'puede_cancelar': false,
        'puede_ver_tecnico': false,
        'puede_ver_cotizacion': false,
        'puede_responder_cotizacion': false,
        'puede_pagar': false,
        'puede_evaluar_servicio': false,
      },
    };
  }

  Map<String, dynamic> _offlineToEstado(OfflineEmergency row) {
    return {
      'incidente_id': row.offlineSyncId,
      'codigo_solicitud': row.offlineSyncId,
      'estado': row.estadoSync,
      'prioridad': '-',
      'tipo_problema': 'emergencia offline',
      'fecha_reporte': row.fechaLocal,
      'resumen_ia':
          'Esta emergencia fue guardada sin conexión y se enviará automáticamente cuando vuelva internet.',
      'vehiculo': {
        'id': row.vehiculoId,
        'placa': 'Pendiente de sincronización',
      },
      'ubicacion': {
        'latitud': row.lat,
        'longitud': row.lng,
      },
      'taller_asignado': null,
      'tecnico_asignado': null,
      'historial': [
        {
          'estado_anterior': null,
          'estado_nuevo': row.estadoSync,
          'comentario': row.error ??
              'Reporte guardado localmente. No se mostrará otra solicitud mientras este reporte esté pendiente.',
          'creado_en': row.fechaLocal,
        }
      ],
      'cotizacion_actual': null,
      'cotizaciones_disponibles': [],
      'pago_actual': null,
      'acciones_disponibles': {
        'puede_cancelar': false,
        'puede_ver_tecnico': false,
        'puede_ver_cotizacion': false,
        'puede_responder_cotizacion': false,
        'puede_pagar': false,
        'puede_evaluar_servicio': false,
      },
    };
  }

  Future<List<OfflineEmergency>> _loadOfflineRows() async {
    final rows = await _offlineStore.list();
    return rows.where((e) => e.estadoSync != 'sincronizado').toList();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() => _loadingSolicitudes = true);
    try {
      final offlineRows = await _loadOfflineRows();
      var serverRows = <Map<String, dynamic>>[];
      try {
        serverRows = await _api.getTrackRequests();
      } catch (_) {
        if (offlineRows.isEmpty) rethrow;
      }
      if (!mounted) return;
      final offlineItems = offlineRows.map(_offlineToSolicitud).toList();
      setState(() {
        _solicitudes = [...offlineItems, ...serverRows];
        _error = '';
        if (_incidenteId.isEmpty && _solicitudes.isNotEmpty) {
          _incidenteId = '${_solicitudes.first['incidente_id']}';
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
    if (_paymentSheetActive) return;
    if (_refreshing || _incidenteId.isEmpty) return;
    _refreshing = true;
    try {
      if (_isOfflineSelection) {
        final rows = await _offlineStore.list();
        OfflineEmergency? offline;
        for (final row in rows) {
          if (row.offlineSyncId == _incidenteId) {
            offline = row;
            break;
          }
        }
        final offlineRow = offline;
        if (offlineRow != null &&
            offlineRow.estadoSync == 'sincronizado' &&
            (offlineRow.incidenteId ?? '').trim().isNotEmpty) {
          if (!mounted) return;
          final syncedIncidenteId = offlineRow.incidenteId!.trim();
          setState(() => _incidenteId = syncedIncidenteId);
        } else if (offlineRow != null) {
          if (!mounted) return;
          setState(() {
            _estado = _offlineToEstado(offlineRow);
            _tecnicoUbicacion = null;
            _error = '';
          });
          return;
        }
      }
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
      final result = await _api.cancelEmergency(_incidenteId, motivo: motivoCtrl.text.trim());
      if (!mounted) return;
      await _refresh();
      await _cargarSolicitudes();
      if (!mounted) return;
      final requierePago = result['requiere_pago'] == true ||
          _stateKey('${_estado?['estado'] ?? ''}') == 'cancelado_con_cobro';
      if (requierePago) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada con cobro por visita. Procesa el pago pendiente.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada correctamente')),
        );
      }
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

  Future<void> _procesarPago() async {
    final cot = _asMap(_estado?['cotizacion_actual']);
    final pago = _asMap(_estado?['pago_actual']);
    final cotId = (cot?['id'] ?? '').toString().trim();
    final pagoId = (pago?['id'] ?? '').toString().trim();
    if (cotId.isEmpty) return;
    String metodo = 'efectivo';
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
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'stripe', child: Text('Stripe PaymentSheet')),
                ],
                onChanged: (v) => setLocalState(() => metodo = (v ?? 'efectivo')),
              ),
              const SizedBox(height: 8),
              if (metodo == 'efectivo')
                TextField(
                  controller: referenciaCtrl,
                  decoration: const InputDecoration(labelText: 'Referencia (opcional)'),
                )
              else
                const Text(
                  'Se abrirá el modal nativo de Stripe dentro de la app.',
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
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (metodo == 'stripe') {
        if (pagoId.isEmpty) {
          throw Exception('El pago aún no está habilitado. Espera a que el técnico complete el servicio.');
        }
        await _pagarConStripePaymentSheet(pagoId);
      } else {
        await _api.processPayment(
          cotizacionId: cotId,
          metodoPago: 'efectivo',
          referencia: referenciaCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      if (metodo == 'stripe') {
        await _mostrarPagoRealizado();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago en efectivo registrado')),
        );
      }
      await _refresh();
      await _cargarSolicitudes();
    } on StripeException catch (e) {
      if (!mounted) return;
      final code = e.error.code.toString().toLowerCase();
      final message = code.contains('cancel')
          ? 'Pago cancelado'
          : (e.error.localizedMessage ?? 'No se pudo completar el pago con Stripe');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _pagarConStripePaymentSheet(String pagoId) async {
    _paymentSheetActive = true;
    _stopAutoRefresh();
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final sheet = await _api.createStripePaymentSheet(pagoId);
      final publishableKey = (sheet['publishableKey'] ?? '').toString().trim();
      final clientSecret = (sheet['paymentIntentClientSecret'] ?? '').toString().trim();
      final customerId = (sheet['customerId'] ?? '').toString().trim();
      final ephemeralKey = (sheet['customerEphemeralKeySecret'] ?? '').toString().trim();

      if (publishableKey.isEmpty || clientSecret.isEmpty || customerId.isEmpty || ephemeralKey.isEmpty) {
        throw Exception('Stripe no devolvió los datos completos para PaymentSheet');
      }

      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'AuxilioSCZ',
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: false,
          paymentMethodOrder: const ['card'],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await Stripe.instance.presentPaymentSheet();
      await _api.confirmStripePaymentSheet(pagoId);
    } finally {
      _paymentSheetActive = false;
      _startAutoRefresh();
    }
  }

  Future<void> _mostrarPagoRealizado() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Pago realizado!'),
        content: const Text('Tu pago fue confirmado correctamente.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
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
    if (_paymentSheetActive) {
      _stopAutoRefresh();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAutoRefresh();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = '${_estado?['estado'] ?? 'sin_datos'}';
    final historial = _asMapList(_estado?['historial']);
    final taller = _asMap(_estado?['taller_asignado']);
    final tecnico = _asMap(_estado?['tecnico_asignado']);
    final cotizacion = _asMap(_estado?['cotizacion_actual']);
    final cotizaciones = _cotizacionesParaCliente;
    final pago = _asMap(_estado?['pago_actual']);
    final ubicacion = _asMap(_estado?['ubicacion']);
    final tallerNombreVisible = (cotizacion?['taller_nombre'] ??
            taller?['nombre'] ??
            _estado?['taller_nombre'] ??
            '-')
        .toString();
    final tecnicoNombreVisible = (_estado?['tecnico_nombre'] ??
            tecnico?['nombre'] ??
            _tecnicoUbicacion?['tecnico_nombre'] ??
            '-')
        .toString();

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
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notificaciones),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
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
                Text('Taller: $tallerNombreVisible'),
                Text('Técnico: $tecnicoNombreVisible'),
                if (ubicacion != null)
                  Text(
                      'Ubicación enviada: ${ubicacion['latitud'] ?? '-'}, ${ubicacion['longitud'] ?? '-'}'),
                if (cotizacion != null)
                  Text(
                      'Cotización: ${cotizacion['monto'] ?? '-'} (${cotizacion['estado'] ?? '-'})'),
                if (cotizaciones.isNotEmpty)
                  Text('Cotizaciones recibidas: ${cotizaciones.length}'),
                if (pago != null) ...[
                  Text('Pago: ${pago['estado'] ?? '-'}'),
                  if (pago['monto'] != null) Text('Monto total: ${pago['monto']}'),
                  if (pago['comision_plataforma'] != null)
                    Text('Comisión plataforma (10%): ${pago['comision_plataforma']}'),
                  if (pago['monto_taller'] != null)
                    Text('Monto neto taller: ${pago['monto_taller']}'),
                ],
                if (_canPay) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _procesarPago,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Procesar pago'),
                  ),
                ] else if (cotizacion == null &&
                    {'trabajo_completado', 'esperando_pago', 'cancelado_con_cobro', 'finalizado'}
                        .contains(_stateKey(estado))) ...[
                  const SizedBox(height: 10),
                  Text(
                    ((_asMap(_estado?['acciones_disponibles'])?['motivo_pago_no_disponible'] ??
                                    'No se puede habilitar el pago porque esta solicitud no tiene cotización aceptada registrada.')
                                .toString()),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ] else if (cotizacion != null && !_isFinalState) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'El pago se habilitará cuando el técnico complete el servicio.',
                    style: TextStyle(color: AppColors.textMuted),
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
          if (cotizaciones.isNotEmpty && _canRespondQuote && !_isFinalState) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Cotizaciones recibidas',
              subtitle: 'Compara precio, tiempo y taller antes de elegir.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...cotizaciones.take(3).map((cot) {
                    final tallerNombre =
                        (cot['taller_nombre'] ?? 'Taller').toString();
                    final monto = cot['monto'] ?? '-';
                    final estadoCot = cot['estado'] ?? '-';
                    final tiempo = cot['tiempo_estimado'] ?? '-';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.garage_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$tallerNombre · $monto Bs · $tiempo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusChip(status: _estadoAmigable('$estadoCot')),
                        ],
                      ),
                    );
                  }),
                  if (cotizaciones.length > 3)
                    Text(
                      '+${cotizaciones.length - 3} cotización(es) más',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _abrirComparacionCotizaciones,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Comparar y seleccionar taller'),
                  ),
                ],
              ),
            ),
          ],
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
          if (_tecnicoUbicacion != null || _canOpenTechnicianTracking) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ubicación del técnico',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Técnico: ${_tecnicoUbicacion?['tecnico_nombre'] ?? tecnicoNombreVisible}'),
                  Text('Estado: ${_estadoAmigable('${_tecnicoUbicacion?['estado_servicio'] ?? _tecnicoUbicacion?['estado'] ?? estado}')}'),
                  Text('Última actualización: ${_tecnicoUbicacion?['ultima_actualizacion'] ?? '-'}'),
                  Text('Lat: ${_tecnicoUbicacion?['latitud_tecnico'] ?? '-'}'),
                  Text('Lng: ${_tecnicoUbicacion?['longitud_tecnico'] ?? '-'}'),
                  if ((_tecnicoUbicacion?['mensaje'] ?? '').toString().isNotEmpty)
                    Text(
                      '${_tecnicoUbicacion?['mensaje']}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  if (_canOpenTechnicianTracking) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.tecnicoLocation,
                        arguments: _incidenteId,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver seguimiento en tiempo real'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Acciones rápidas',
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _incidenteId.isEmpty
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            AppRoutes.solicitudChat,
                            arguments: _incidenteId,
                          ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat con el taller'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _sendGpsAgain,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Enviar ubicación nuevamente'),
                ),
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
