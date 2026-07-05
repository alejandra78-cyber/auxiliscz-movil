import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Detección de choques en segundo plano (Foreground Service).
///
/// El TaskHandler corre en un AISLADO SEPARADO del de la UI, por lo que
/// sigue leyendo el acelerómetro aunque el usuario esté en Google Maps,
/// Waze o WhatsApp, o incluso si cierra la app desde recientes.
///
/// Comunicación entre aislados (flutter_foreground_task):
///   - Aislado → UI:  FlutterForegroundTask.sendDataToMain(...)
///                    (la UI escucha con addTaskDataCallback)
///   - UI → Aislado:  FlutterForegroundTask.sendDataToTask(...)
///                    (llega al handler en onReceiveData)
///   - Botón de la notificación → onNotificationButtonPressed (en el aislado)
/// ═══════════════════════════════════════════════════════════════════

// Claves de SharedPreferences compartidas entre la UI y el aislado.
const kPrefsApiBaseUrl = 'crash_api_base_url';
const kPrefsAccessToken = 'access_token'; // la misma que usa TokenStorage
const kPrefsContactos = 'contactos_emergencia';

// Algoritmo de detección.
const kUmbralImpacto = 20.0; // m/s² (magnitud vectorial)
const kVentanaImpactoMs = 200; // dos picos dentro de esta ventana = choque
const kSegundosCuentaRegresiva = 15;
const kCooldownTrasEventoSeg = 30;

// Eventos aislado → UI.
const kEventoChoqueDetectado = 'crash_suspected';
const kEventoCuentaRegresiva = 'crash_countdown';
const kEventoCancelado = 'crash_cancelled';
const kEventoReportado = 'accident_reported';
const kEventoReporteFallo = 'accident_report_failed';

// Comandos UI → aislado.
const kComandoEstoyBien = 'estoy_bien';
const kComandoSimularChoque = 'simulate_crash';

const _kBotonEstoyBien = 'btn_estoy_bien';

/// Entry-point del aislado del servicio. DEBE ser función top-level
/// con @pragma para sobrevivir al tree-shaking en release.
@pragma('vm:entry-point')
void startCrashDetectionCallback() {
  FlutterForegroundTask.setTaskHandler(CrashDetectionHandler());
}

class CrashDetectionHandler extends TaskHandler {
  StreamSubscription<AccelerometerEvent>? _sensorSub;
  DateTime? _primerPico;
  double _magnitudPico = 0;

  Timer? _cuentaRegresiva;
  int _segundosRestantes = 0;
  DateTime? _finUltimoEvento;

  bool get _enAlerta => _cuentaRegresiva != null;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sensorSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometer);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No usamos eventos periódicos: el acelerómetro es nuestro reloj.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sensorSub?.cancel();
    _cuentaRegresiva?.cancel();
  }

  // ── Detección de impacto ──────────────────────────────────────────

  void _onAccelerometer(AccelerometerEvent e) {
    if (_enAlerta) return;
    if (_finUltimoEvento != null &&
        DateTime.now().difference(_finUltimoEvento!).inSeconds <
            kCooldownTrasEventoSeg) {
      return; // periodo de gracia tras un evento reciente
    }

    final magnitud = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitud <= kUmbralImpacto) return;

    final ahora = DateTime.now();
    if (_primerPico != null &&
        ahora.difference(_primerPico!).inMilliseconds <= kVentanaImpactoMs) {
      // Segundo pico dentro de la ventana → impacto confirmado.
      final pico = math.max(_magnitudPico, magnitud);
      _primerPico = null;
      _iniciarAlerta(pico);
    } else {
      _primerPico = ahora;
      _magnitudPico = magnitud;
    }
  }

  // ── Alerta con cuenta regresiva de 15s ────────────────────────────

  void _iniciarAlerta(double magnitud) {
    _segundosRestantes = kSegundosCuentaRegresiva;

    // Intentar traer la app al frente para mostrar el pop-up
    // (si Android lo bloquea, la notificación de alta prioridad es el respaldo).
    FlutterForegroundTask.launchApp('/');

    FlutterForegroundTask.sendDataToMain({
      'event': kEventoChoqueDetectado,
      'magnitud': magnitud,
      'restantes': _segundosRestantes,
    });
    _actualizarNotificacionAlerta();

    _cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (t) async {
      _segundosRestantes--;
      if (_segundosRestantes <= 0) {
        t.cancel();
        _cuentaRegresiva = null;
        await _reportarAccidente(magnitud);
      } else {
        FlutterForegroundTask.sendDataToMain({
          'event': kEventoCuentaRegresiva,
          'restantes': _segundosRestantes,
        });
        _actualizarNotificacionAlerta();
      }
    });
  }

  void _actualizarNotificacionAlerta() {
    FlutterForegroundTask.updateService(
      notificationTitle: '🚨 ¿Tuviste un accidente?',
      notificationText:
          'Reportaremos automáticamente en $_segundosRestantes s. '
          'Pulsa ESTOY BIEN para cancelar.',
      notificationButtons: [
        const NotificationButton(id: _kBotonEstoyBien, text: 'ESTOY BIEN'),
      ],
    );
  }

  void _cancelarAlerta() {
    if (!_enAlerta) return;
    _cuentaRegresiva?.cancel();
    _cuentaRegresiva = null;
    _finUltimoEvento = DateTime.now();
    FlutterForegroundTask.sendDataToMain({'event': kEventoCancelado});
    _restaurarNotificacionNormal();
  }

  void _restaurarNotificacionNormal() {
    FlutterForegroundTask.updateService(
      notificationTitle: 'AuxilioSCZ está monitoreando tu viaje',
      notificationText: 'Detección de choques activa',
      notificationButtons: [],
    );
  }

  // ── Reporte automático del accidente ──────────────────────────────

  Future<void> _reportarAccidente(double magnitud) async {
    _finUltimoEvento = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      // Refrescar: este aislado puede tener caché viejo de prefs.
      await prefs.reload();
      final baseUrl = prefs.getString(kPrefsApiBaseUrl) ?? '';
      final token = prefs.getString(kPrefsAccessToken) ?? '';
      final contactosRaw = prefs.getString(kPrefsContactos) ?? '[]';

      if (baseUrl.isEmpty || token.isEmpty) {
        throw Exception('Sin sesión o URL de API para reportar');
      }

      // Ubicación exacta (última conocida como respaldo rápido).
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) throw Exception('Sin ubicación disponible');

      List<dynamic> contactos;
      try {
        contactos = jsonDecode(contactosRaw) as List<dynamic>;
      } catch (_) {
        contactos = [];
      }

      final resp = await http
          .post(
            Uri.parse('$baseUrl/emergencia/report_accident'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'lat': pos.latitude,
              'lng': pos.longitude,
              'fecha_local': DateTime.now().toIso8601String(),
              'magnitud': magnitud,
              'contactos': contactos,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        FlutterForegroundTask.sendDataToMain({
          'event': kEventoReportado,
          'incidente_id': data['incidente_id'],
          'contactos_notificados': data['contactos_notificados'],
        });
        FlutterForegroundTask.updateService(
          notificationTitle: '✅ Accidente reportado',
          notificationText:
              'Talleres cercanos y contactos notificados. Ayuda en camino.',
          notificationButtons: [],
        );
      } else {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'event': kEventoReporteFallo,
        'error': '$e',
      });
      FlutterForegroundTask.updateService(
        notificationTitle: '⚠️ No se pudo reportar el accidente',
        notificationText: 'Abre la app y reporta manualmente. ($e)',
        notificationButtons: [],
      );
    }
  }

  // ── Entradas externas ─────────────────────────────────────────────

  @override
  void onReceiveData(Object data) {
    if (data == kComandoEstoyBien) {
      _cancelarAlerta();
    } else if (data == kComandoSimularChoque && !_enAlerta) {
      _iniciarAlerta(25.0); // magnitud simulada para la demo
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _kBotonEstoyBien) _cancelarAlerta();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}

/// ═══════════════════════════════════════════════════════════════════
/// API estática que usa la UI para controlar el servicio.
/// ═══════════════════════════════════════════════════════════════════
class CrashDetectionService {
  CrashDetectionService._();

  static bool _inicializado = false;

  static void init() {
    if (_inicializado) return;
    _inicializado = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'auxilioscz_modo_viaje',
        channelName: 'Modo Viaje — Detección de choques',
        channelDescription:
            'Monitoreo del acelerómetro durante el viaje para detectar accidentes',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        enableVibration: true,
        playSound: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Pide el permiso de notificaciones (Android 13+), requisito para
  /// que el Foreground Service muestre su notificación persistente.
  static Future<bool> solicitarPermisoNotificaciones() async {
    final actual = await FlutterForegroundTask.checkNotificationPermission();
    if (actual == NotificationPermission.granted) return true;
    final pedido = await FlutterForegroundTask.requestNotificationPermission();
    return pedido == NotificationPermission.granted;
  }

  static Future<bool> estaCorriendo() =>
      FlutterForegroundTask.isRunningService;

  /// Arranca el servicio. [apiBaseUrl] se persiste para que el aislado
  /// sepa a qué backend reportar (el token ya está en SharedPreferences).
  static Future<bool> iniciar({required String apiBaseUrl}) async {
    init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsApiBaseUrl, apiBaseUrl);

    if (await FlutterForegroundTask.isRunningService) return true;

    final resultado = await FlutterForegroundTask.startService(
      serviceId: 512,
      notificationTitle: 'AuxilioSCZ está monitoreando tu viaje',
      notificationText: 'Detección de choques activa',
      callback: startCrashDetectionCallback,
    );
    return resultado is ServiceRequestSuccess;
  }

  /// Detiene el servicio limpiamente (al desactivar el Modo Viaje).
  static Future<void> detener() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// El usuario confirmó que está bien (desde el diálogo de la UI).
  static void confirmarEstoyBien() {
    FlutterForegroundTask.sendDataToTask(kComandoEstoyBien);
  }

  /// Dispara un choque simulado (para demos/pruebas sin golpear el teléfono).
  static void simularChoque() {
    FlutterForegroundTask.sendDataToTask(kComandoSimularChoque);
  }
}
