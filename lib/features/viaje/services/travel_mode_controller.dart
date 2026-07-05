import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import 'crash_detection_service.dart';

/// Resultado del flujo de permisos de ubicación.
enum PermisoUbicacionResultado {
  concedido,
  denegado,
  denegadoPermanente,
  gpsDesactivado,
}

/// Destino seleccionado por el usuario.
class DestinoViaje {
  const DestinoViaje({
    required this.nombre,
    required this.punto,
  });

  final String nombre;
  final LatLng punto;
}

/// ViewModel del Modo Viaje (equivalente MVVM con ChangeNotifier).
///
/// - Activa/desactiva el modo y lo persiste en SharedPreferences.
/// - Maneja el flujo de permisos de ubicación en tiempo de ejecución.
/// - Obtiene la ubicación actual (FusedLocationProvider vía geolocator).
/// - Busca destinos por texto usando Nominatim (OpenStreetMap, sin API key).
class TravelModeController extends ChangeNotifier {
  TravelModeController._();

  static final TravelModeController instance = TravelModeController._();

  static const _prefsKeyActivo = 'modo_viaje_activo';

  bool _activo = false;
  bool _cargado = false;
  bool _buscando = false;
  LatLng? _ubicacionActual;
  DestinoViaje? _destino;
  List<DestinoViaje> _resultadosBusqueda = const [];

  bool get activo => _activo;
  bool get cargado => _cargado;
  bool get buscando => _buscando;
  LatLng? get ubicacionActual => _ubicacionActual;
  DestinoViaje? get destino => _destino;
  List<DestinoViaje> get resultadosBusqueda => _resultadosBusqueda;

  /// Carga el estado persistido (llamar al iniciar la pantalla principal).
  Future<void> cargarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    _activo = prefs.getBool(_prefsKeyActivo) ?? false;
    _cargado = true;
    notifyListeners();
  }

  /// Solicita permisos de ubicación en tiempo de ejecución.
  Future<PermisoUbicacionResultado> solicitarPermisos() async {
    final gpsActivo = await Geolocator.isLocationServiceEnabled();
    if (!gpsActivo) return PermisoUbicacionResultado.gpsDesactivado;

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    switch (permiso) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return PermisoUbicacionResultado.concedido;
      case LocationPermission.deniedForever:
        return PermisoUbicacionResultado.denegadoPermanente;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return PermisoUbicacionResultado.denegado;
    }
  }

  /// Activa el Modo Viaje, persiste el estado y arranca el servicio de
  /// detección de choques en segundo plano (solo Android).
  Future<void> activar() async {
    _activo = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyActivo, true);
    await _iniciarDeteccionChoques();
  }

  /// Desactiva el Modo Viaje, limpia el destino, persiste el estado y
  /// detiene limpiamente el servicio de detección de choques.
  Future<void> desactivar() async {
    _activo = false;
    _destino = null;
    _resultadosBusqueda = const [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyActivo, false);
    if (_esAndroid) await CrashDetectionService.detener();
  }

  bool get _esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// true si el Foreground Service quedó corriendo.
  bool deteccionActiva = false;

  Future<void> _iniciarDeteccionChoques() async {
    if (!_esAndroid) return; // sensores en background: solo Android
    // Android 13+: la notificación persistente requiere este permiso.
    await CrashDetectionService.solicitarPermisoNotificaciones();
    deteccionActiva = await CrashDetectionService.iniciar(
      apiBaseUrl: AppConfig.baseUrl,
    );
    notifyListeners();
  }

  /// Reintenta arrancar la detección (p.ej. si el permiso fue negado antes).
  Future<bool> reintentarDeteccion() async {
    await _iniciarDeteccionChoques();
    return deteccionActiva;
  }

  /// Obtiene la ubicación actual (última conocida primero, luego GPS).
  Future<LatLng?> obtenerUbicacionActual() async {
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) {
        _ubicacionActual = LatLng(ultima.latitude, ultima.longitude);
        notifyListeners();
      }
      final pos = await Geolocator.getCurrentPosition();
      _ubicacionActual = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
      return _ubicacionActual;
    } catch (_) {
      return _ubicacionActual;
    }
  }

  /// Busca destinos por texto con Nominatim (geocodificación gratuita OSM).
  Future<void> buscarDestino(String consulta) async {
    final texto = consulta.trim();
    if (texto.isEmpty) return;
    _buscando = true;
    _resultadosBusqueda = const [];
    notifyListeners();
    try {
      // Sesgar resultados hacia la posición actual si la conocemos.
      final cerca = _ubicacionActual != null
          ? '&viewbox=${_ubicacionActual!.longitude - 0.3},'
              '${_ubicacionActual!.latitude + 0.3},'
              '${_ubicacionActual!.longitude + 0.3},'
              '${_ubicacionActual!.latitude - 0.3}'
          : '';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(texto)}'
        '&format=json&limit=6&addressdetails=0$cerca',
      );
      final resp = await http.get(
        uri,
        headers: {'User-Agent': 'AuxilioSCZ/1.0 (app movil)'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        _resultadosBusqueda = data
            .map((e) => e as Map<String, dynamic>)
            .map(
              (e) => DestinoViaje(
                nombre: (e['display_name'] ?? '').toString(),
                punto: LatLng(
                  double.parse(e['lat'].toString()),
                  double.parse(e['lon'].toString()),
                ),
              ),
            )
            .toList();
      }
    } catch (_) {
      _resultadosBusqueda = const [];
    } finally {
      _buscando = false;
      notifyListeners();
    }
  }

  /// Selecciona un destino de los resultados (o uno manual).
  void seleccionarDestino(DestinoViaje destino) {
    _destino = destino;
    _resultadosBusqueda = const [];
    notifyListeners();
  }

  /// Limpia el destino seleccionado.
  void limpiarDestino() {
    _destino = null;
    notifyListeners();
  }
}
