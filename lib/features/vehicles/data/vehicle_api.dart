import '../../../core/network/api_client.dart';

class VehicleApi {
  VehicleApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> registerVehicle({
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
  }) async {
    final res = await _apiClient.post('/clientes/vehiculos', body: {
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo registrar vehículo: ${res.body}');
    }
  }
}
