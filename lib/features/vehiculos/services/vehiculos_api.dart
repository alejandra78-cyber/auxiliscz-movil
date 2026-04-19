import 'dart:convert';

import '../../../core/network/api_client.dart';

class VehicleOption {
  VehicleOption({
    required this.id,
    required this.placa,
    this.marca,
    this.modelo,
  });

  final String id;
  final String placa;
  final String? marca;
  final String? modelo;

  String get label {
    final parts = <String>[placa];
    if ((marca ?? '').isNotEmpty) parts.add(marca!);
    if ((modelo ?? '').isNotEmpty) parts.add(modelo!);
    return parts.join(' - ');
  }

  factory VehicleOption.fromJson(Map<String, dynamic> json) {
    return VehicleOption(
      id: (json['id'] ?? '').toString(),
      placa: (json['placa'] ?? '').toString(),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
    );
  }
}

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

  Future<List<VehicleOption>> myVehicles() async {
    final res = await _apiClient.get('/clientes/vehiculos');
    if (res.statusCode != 200) {
      throw Exception('No se pudo obtener vehículos: ${res.body}');
    }

    final raw = res.body.trim();
    if (raw.isEmpty || raw == 'null') return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VehicleOption.fromJson)
        .where((v) => v.id.isNotEmpty && v.placa.isNotEmpty)
        .toList();
  }
}
