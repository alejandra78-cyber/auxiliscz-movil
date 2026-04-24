import 'dart:convert';

import '../../../core/network/api_client.dart';

class VehicleOption {
  VehicleOption({
    required this.id,
    required this.placa,
    this.marca,
    this.modelo,
    this.anio,
    this.color,
    this.tipo,
    this.observacion,
    this.activo = true,
  });

  final String id;
  final String placa;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? color;
  final String? tipo;
  final String? observacion;
  final bool activo;

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
      anio: json['anio'] is int ? json['anio'] as int : int.tryParse('${json['anio'] ?? ''}'),
      color: json['color']?.toString(),
      tipo: json['tipo']?.toString(),
      observacion: json['observacion']?.toString(),
      activo: json['activo'] is bool ? json['activo'] as bool : true,
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
    String? color,
    String? tipo,
    String? observacion,
  }) async {
    final body = <String, dynamic>{
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
    };
    if ((color ?? '').trim().isNotEmpty) body['color'] = color!.trim();
    if ((tipo ?? '').trim().isNotEmpty) body['tipo'] = tipo!.trim();
    if ((observacion ?? '').trim().isNotEmpty) body['observacion'] = observacion!.trim();
    final res = await _apiClient.post('/clientes/vehiculos', body: body);
    if (res.statusCode != 200) {
      throw Exception('No se pudo registrar vehículo: ${res.body}');
    }
  }

  Future<void> updateVehicle({
    required String id,
    required String marca,
    required String modelo,
    required int anio,
    String? color,
    String? tipo,
    String? observacion,
  }) async {
    final body = <String, dynamic>{
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
    };
    if ((color ?? '').trim().isNotEmpty) body['color'] = color!.trim();
    if ((tipo ?? '').trim().isNotEmpty) body['tipo'] = tipo!.trim();
    if ((observacion ?? '').trim().isNotEmpty) body['observacion'] = observacion!.trim();

    final res = await _apiClient.put('/clientes/vehiculos/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('No se pudo actualizar vehículo: ${res.body}');
    }
  }

  Future<void> deactivateVehicle(String id) async {
    final res = await _apiClient.patch('/clientes/vehiculos/$id/desactivar');
    if (res.statusCode != 200) {
      throw Exception('No se pudo desactivar vehículo: ${res.body}');
    }
  }

  Future<List<VehicleOption>> myVehicles({bool onlyActive = true}) async {
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
        .where((v) => !onlyActive || v.activo)
        .toList();
  }
}
