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
    XFile? foto,
    XFile? audio,
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
    final res = await _apiClient.patch('/emergencias/solicitud/$incidenteId/cancelar');
    if (res.statusCode != 200) {
      throw Exception('No se pudo cancelar la solicitud: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getTechnicianLocation(String incidenteId) async {
    final res = await _apiClient.get('/clientes/solicitudes/$incidenteId/tecnico-ubicacion');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener ubicación del técnico: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
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
    final res = await _apiClient.get('/clientes/solicitudes/seguimiento');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener solicitudes: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
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
}
