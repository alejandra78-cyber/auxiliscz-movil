import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';

class EmergenciesApi {
  EmergenciesApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<String> reportEmergency({
    required String vehiculoId,
    required double lat,
    required double lng,
    required String descripcion,
  }) async {
    final res = await _apiClient.multipart('/emergencias/reportar', fields: {
      'vehiculo_id': vehiculoId,
      'lat': lat.toString(),
      'lng': lng.toString(),
      'descripcion': descripcion,
    });

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

  Future<void> uploadImage({required String incidenteId, required String imagePath}) async {
    final file = await http.MultipartFile.fromPath('imagen', imagePath);
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
}
