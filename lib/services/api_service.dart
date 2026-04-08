import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl =
      'http://localhost:8000/api'; // Para desarrollo web
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Para emulador Android
  // static const String baseUrl = 'http://localhost:8000/api'; // Para iOS simulator

  Future<Map<String, dynamic>> crearIncidente({
    required String vehiculoId,
    required double lat,
    required double lng,
    required String descripcion,
    XFile? foto,
    String? audioPath,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/incidentes/'),
      );

      request.fields['vehiculo_id'] = vehiculoId;
      request.fields['tipo_incidente'] = 'emergencia';
      request.fields['descripcion'] = descripcion;
      request.fields['ubicacion'] = '$lat,$lng';
      request.fields['estado'] = 'pendiente';

      if (foto != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
      }

      if (audioPath != null) {
        request.files
            .add(await http.MultipartFile.fromPath('audio', audioPath));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 201) {
        return {'incidente_id': jsonResponse['id'].toString()};
      } else {
        throw Exception('Error al crear incidente: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerIncidente(String incidenteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/incidentes/$incidenteId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener incidente');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerEstadoIncidente(
      String incidenteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/incidentes/$incidenteId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener estado del incidente');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTalleresCercanos(
    double latitud,
    double longitud,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/talleres/cercanos?lat=$latitud&lng=$longitud'),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Error al obtener talleres cercanos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> calificarServicio(
      String incidenteId, int calificacion, String comentario) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/incidentes/$incidenteId/calificar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'calificacion': calificacion,
          'comentario': comentario,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al calificar servicio');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
