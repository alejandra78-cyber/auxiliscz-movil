import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

class EmergenciesApi {
  EmergenciesApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<String> reportEmergency({
    required String vehiculoId,
    required String tipo,
    required double lat,
    required double lng,
    required String descripcion,
    List<XFile> fotos = const [],
    XFile? audio,
  }) async {
    final files = <http.MultipartFile>[];
    for (var i = 0; i < fotos.length; i++) {
      final foto = fotos[i];
      final fotoBytes = await foto.readAsBytes();
      files.add(
        http.MultipartFile.fromBytes(
          i == 0 ? 'foto' : 'fotos',
          fotoBytes,
          filename: foto.name.isNotEmpty ? foto.name : 'foto_emergencia.jpg',
        ),
      );
    }
    if (audio != null) {
      final audioBytes = await audio.readAsBytes();
      files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: audio.name.isNotEmpty ? audio.name : 'audio_emergencia.webm',
        ),
      );
    }

    final res = await _apiClient.multipart('/emergencias/reportar', fields: {
      'vehiculo_id': vehiculoId,
      'tipo': tipo,
      'lat': lat.toString(),
      'lng': lng.toString(),
      'descripcion': descripcion,
    }, files: files);

    final raw = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('No se pudo reportar emergencia: $raw');
    }
    final map = ApiClient.decodeJsonMap(raw);
    return (map['incidente_id'] ?? '').toString();
  }

  Future<void> sendGps({required String incidenteId, required double lat, required double lng}) async {
    final res = await _apiClient.patch('/emergencias/solicitud/$incidenteId/ubicacion', body: {
      'lat': lat,
      'lng': lng,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo enviar ubicación: ${res.body}');
    }
  }

  Future<void> uploadImage({required String incidenteId, required XFile image}) async {
    final bytes = await image.readAsBytes();
    final file = http.MultipartFile.fromBytes(
      'imagen',
      bytes,
      filename: image.name.isNotEmpty ? image.name : 'evidencia.jpg',
    );
    final res = await _apiClient.multipart('/emergencias/solicitud/$incidenteId/imagenes', fields: {}, files: [file]);
    final raw = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('No se pudo subir imagen: $raw');
    }
  }

  Future<Map<String, dynamic>> getEmergencyStatus(String incidenteId) async {
    final res = await _apiClient.get('/clientes/solicitudes/$incidenteId');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    // Fallback de compatibilidad.
    final legacy = await _apiClient.get('/emergencias/solicitud/$incidenteId');
    if (legacy.statusCode != 200) {
      throw Exception('No se pudo consultar estado: ${legacy.body}');
    }
    return jsonDecode(legacy.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLatestEmergencyStatus() async {
    final res = await _apiClient.get('/clientes/solicitudes/ultima/estado');
    if (res.statusCode != 200) {
      throw Exception('No se pudo consultar tu última solicitud: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> cancelEmergency(String incidenteId, {String? motivo}) async {
    final res = await _apiClient.patch(
      '/clientes/solicitudes/$incidenteId/cancelar',
      body: {
        if ((motivo ?? '').trim().isNotEmpty) 'motivo_cancelacion': motivo!.trim(),
      },
    );
    if (res.statusCode == 200) return;

    final legacy = await _apiClient.patch(
      '/emergencias/solicitud/$incidenteId/cancelar',
      body: {
        if ((motivo ?? '').trim().isNotEmpty) 'motivo_cancelacion': motivo!.trim(),
      },
    );
    if (legacy.statusCode != 200) {
      throw Exception('No se pudo cancelar la solicitud: ${legacy.body}');
    }
  }

  Future<Map<String, dynamic>> getTechnicianLocation(String incidenteId) async {
    final res = await _apiClient.get('/clientes/solicitudes/$incidenteId/ubicacion-tecnico');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener ubicación del técnico: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyActiveServicesAsTechnician() async {
    final res = await _apiClient.get('/taller/mi-taller/servicios/activos');
    if (res.statusCode != 200) {
      throw Exception('No se pudieron obtener servicios activos: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> updateMyTechnicianLocation({required double lat, required double lng}) async {
    final res = await _apiClient.patch('/taller/tecnicos/mi-ubicacion', body: {
      'lat': lat,
      'lng': lng,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo actualizar ubicación del técnico: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String incidenteId) async {
    final res = await _apiClient.get('/emergencias/solicitud/$incidenteId/mensajes');
    if (res.statusCode != 200) {
      throw Exception('No se pudieron obtener mensajes: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> sendMessage(String incidenteId, String texto) async {
    final res = await _apiClient.post('/emergencias/solicitud/$incidenteId/mensajes', body: {
      'texto': texto,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo enviar mensaje: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getTrackRequests() async {
    final res = await _apiClient.get('/clientes/solicitudes');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    // Fallback legacy.
    final legacy = await _apiClient.get('/clientes/solicitudes/seguimiento');
    if (legacy.statusCode != 200) {
      throw Exception('No se pudo obtener solicitudes: ${legacy.body}');
    }
    final decoded = jsonDecode(legacy.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getNotifications({String? incidenteId}) async {
    final query = (incidenteId != null && incidenteId.isNotEmpty)
        ? '?incidente_id=$incidenteId'
        : '';
    final res = await _apiClient.get('/emergencias/notificaciones$query');
    if (res.statusCode != 200) {
      throw Exception('No se pudieron obtener notificaciones: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> acceptQuote(String cotizacionId, {String? observaciones}) async {
    final res = await _apiClient.post('/pagos/cliente/cotizaciones/$cotizacionId/aceptar', body: {
      if ((observaciones ?? '').trim().isNotEmpty) 'observaciones': observaciones!.trim(),
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo aceptar cotización: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectQuote(String cotizacionId, {String? observaciones}) async {
    final res = await _apiClient.post('/pagos/cliente/cotizaciones/$cotizacionId/rechazar', body: {
      if ((observaciones ?? '').trim().isNotEmpty) 'observaciones': observaciones!.trim(),
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo rechazar cotización: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processPayment({
    required String cotizacionId,
    required String metodoPago,
    String? comprobanteUrl,
    String? referencia,
  }) async {
    final res = await _apiClient.post('/pagos/cliente/pagos/procesar', body: {
      'cotizacion_id': cotizacionId,
      'metodo_pago': metodoPago,
      if ((comprobanteUrl ?? '').trim().isNotEmpty) 'comprobante_url': comprobanteUrl!.trim(),
      if ((referencia ?? '').trim().isNotEmpty) 'referencia': referencia!.trim(),
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo procesar pago: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> evaluateService({
    required String incidenteId,
    required int calificacion,
    String? comentario,
  }) async {
    final res = await _apiClient.post('/clientes/solicitudes/$incidenteId/evaluar', body: {
      'calificacion': calificacion,
      if ((comentario ?? '').trim().isNotEmpty) 'comentario': comentario!.trim(),
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo registrar evaluación: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistoryServices() async {
    final res = await _apiClient.get('/clientes/historial-servicios');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener historial: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }
}
