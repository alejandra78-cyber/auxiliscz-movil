import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

class EmergenciesApi {
  EmergenciesApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> reportEmergencyFull({
    required String vehiculoId,
    required String tipo,
    required double lat,
    required double lng,
    required String descripcion,
    XFile? foto,
    String? audioPath,
  }) async {
    final files = <http.MultipartFile>[];

    if (foto != null) {
      final fotoBytes = await foto.readAsBytes();
      files.add(
        http.MultipartFile.fromBytes(
          'foto',
          fotoBytes,
          filename: foto.name.isNotEmpty ? foto.name : 'foto_emergencia.jpg',
        ),
      );
    }

    if (audioPath != null && audioPath.isNotEmpty) {
      files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          filename: 'audio_emergencia.m4a',
        ),
      );
    }

    final res = await _apiClient.multipart(
      '/emergencias/reportar',
      fields: {
        'vehiculo_id': vehiculoId,
        'tipo': tipo,
        'lat': lat.toString(),
        'lng': lng.toString(),
        'descripcion': descripcion,
      },
      files: files,
    );

    final raw = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('No se pudo reportar emergencia: $raw');
    }

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> sendGps(
      {required String incidenteId,
      required double lat,
      required double lng}) async {
    final res = await _apiClient
        .patch('/emergencias/solicitud/$incidenteId/ubicacion', body: {
      'lat': lat,
      'lng': lng,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo enviar ubicación: ${res.body}');
    }
  }

  Future<void> uploadImage(
      {required String incidenteId, required XFile image}) async {
    final bytes = await image.readAsBytes();
    final file = http.MultipartFile.fromBytes(
      'imagen',
      bytes,
      filename: image.name.isNotEmpty ? image.name : 'evidencia.jpg',
    );
    final res = await _apiClient.multipart(
        '/emergencias/solicitud/$incidenteId/imagenes',
        fields: {},
        files: [file]);
    final raw = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('No se pudo subir imagen: $raw');
    }
  }

  Future<Map<String, dynamic>> getEmergencyStatus(String incidenteId) async {
    final res = await _apiClient.get('/emergencias/solicitud/$incidenteId');
    if (res.statusCode != 200) {
      throw Exception('No se pudo consultar estado: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLatestEmergencyStatus() async {
    final res = await _apiClient.get('/clientes/solicitudes/ultima/estado');
    if (res.statusCode != 200) {
      throw Exception('No se pudo consultar tu última solicitud: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> cancelEmergency(String incidenteId) async {
    final res =
        await _apiClient.patch('/emergencias/solicitud/$incidenteId/cancelar');
    if (res.statusCode != 200) {
      throw Exception('No se pudo cancelar la solicitud: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getTechnicianLocation(String incidenteId) async {
    final res = await _apiClient
        .get('/clientes/solicitudes/$incidenteId/tecnico-ubicacion');
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

  Future<void> updateMyTechnicianLocation(
      {required double lat, required double lng}) async {
    final res = await _apiClient.patch('/taller/tecnicos/mi-ubicacion', body: {
      'lat': lat,
      'lng': lng,
    });
    if (res.statusCode != 200) {
      throw Exception(
          'No se pudo actualizar ubicación del técnico: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String incidenteId) async {
    final res =
        await _apiClient.get('/emergencias/solicitud/$incidenteId/mensajes');
    if (res.statusCode != 200) {
      throw Exception('No se pudieron obtener mensajes: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> sendMessage(String incidenteId, String texto) async {
    final res = await _apiClient
        .post('/emergencias/solicitud/$incidenteId/mensajes', body: {
      'texto': texto,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo enviar mensaje: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getTrackRequests() async {
    final res = await _apiClient.get('/clientes/solicitudes/seguimiento');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener solicitudes: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getNotifications(
      {String? incidenteId}) async {
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

  Future<Map<String, dynamic>> evaluateService({
    required String incidenteId,
    required int estrellas,
    String? comentario,
  }) async {
    final res = await _apiClient.post(
      '/clientes/solicitudes/$incidenteId/evaluar',
      body: {
        'estrellas': estrellas,
        'comentario': comentario,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudo evaluar el servicio: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processPayment({
    required String incidenteId,
    required String metodo,
  }) async {
    final res = await _apiClient.post(
      '/pagos/procesar',
      body: {
        'solicitud_id': incidenteId,
        'metodo': metodo,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudo procesar el pago: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getServiceHistory() async {
    final res = await _apiClient.get('/clientes/servicios/historial');

    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener historial: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> completeTechnicianService(String incidenteId) async {
    final res = await _apiClient.patch(
      '/taller/mi-taller/servicios/$incidenteId/completar',
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudo completar el servicio: ${res.body}');
    }
  }
}
