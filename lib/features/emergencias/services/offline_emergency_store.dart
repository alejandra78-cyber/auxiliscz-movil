import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineEmergency {
  OfflineEmergency({
    required this.offlineSyncId,
    required this.vehiculoId,
    required this.lat,
    required this.lng,
    required this.descripcion,
    required this.fechaLocal,
    required this.estadoSync,
    this.fotoPaths = const [],
    this.audioPath,
    this.error,
    this.incidenteId,
  });

  final String offlineSyncId;
  final String vehiculoId;
  final double lat;
  final double lng;
  final String descripcion;
  final String fechaLocal;
  final String estadoSync;
  final List<String> fotoPaths;
  final String? audioPath;
  final String? error;
  final String? incidenteId;

  OfflineEmergency copyWith({
    String? estadoSync,
    String? error,
    String? incidenteId,
  }) {
    return OfflineEmergency(
      offlineSyncId: offlineSyncId,
      vehiculoId: vehiculoId,
      lat: lat,
      lng: lng,
      descripcion: descripcion,
      fechaLocal: fechaLocal,
      estadoSync: estadoSync ?? this.estadoSync,
      fotoPaths: fotoPaths,
      audioPath: audioPath,
      error: error,
      incidenteId: incidenteId ?? this.incidenteId,
    );
  }

  Map<String, dynamic> toJson() => {
        'offline_sync_id': offlineSyncId,
        'vehiculo_id': vehiculoId,
        'lat': lat,
        'lng': lng,
        'descripcion': descripcion,
        'fecha_local': fechaLocal,
        'estado_sync': estadoSync,
        'foto_paths': fotoPaths,
        'audio_path': audioPath,
        'error': error,
        'incidente_id': incidenteId,
      };

  factory OfflineEmergency.fromJson(Map<String, dynamic> json) {
    return OfflineEmergency(
      offlineSyncId: (json['offline_sync_id'] ?? '').toString(),
      vehiculoId: (json['vehiculo_id'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      descripcion: (json['descripcion'] ?? '').toString(),
      fechaLocal: (json['fecha_local'] ?? '').toString(),
      estadoSync: (json['estado_sync'] ?? 'pendiente_sincronizacion').toString(),
      fotoPaths: ((json['foto_paths'] as List?) ?? const []).map((e) => e.toString()).toList(),
      audioPath: json['audio_path']?.toString(),
      error: json['error']?.toString(),
      incidenteId: json['incidente_id']?.toString(),
    );
  }
}

class OfflineEmergencyStore {
  static const _key = 'cu30_offline_emergencies';

  Future<List<OfflineEmergency>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().map(OfflineEmergency.fromJson).toList();
  }

  Future<void> saveAll(List<OfflineEmergency> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rows.map((e) => e.toJson()).toList()));
  }

  Future<OfflineEmergency> add({
    required String vehiculoId,
    required double lat,
    required double lng,
    required String descripcion,
    required List<XFile> fotos,
    XFile? audio,
  }) async {
    final now = DateTime.now();
    final syncId = 'OFF-EMG-${now.millisecondsSinceEpoch}';
    final dir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${dir.path}/cu30_offline_emergencias/$syncId');
    await offlineDir.create(recursive: true);

    final copiedPhotos = <String>[];
    for (var i = 0; i < fotos.length; i++) {
      final source = File(fotos[i].path);
      if (!await source.exists()) continue;
      final target = File('${offlineDir.path}/foto_$i${_extension(fotos[i].path, '.jpg')}');
      await source.copy(target.path);
      copiedPhotos.add(target.path);
    }

    String? copiedAudio;
    if (audio != null) {
      final source = File(audio.path);
      if (await source.exists()) {
        final target = File('${offlineDir.path}/audio${_extension(audio.path, '.m4a')}');
        await source.copy(target.path);
        copiedAudio = target.path;
      }
    }

    final row = OfflineEmergency(
      offlineSyncId: syncId,
      vehiculoId: vehiculoId,
      lat: lat,
      lng: lng,
      descripcion: descripcion,
      fechaLocal: now.toIso8601String(),
      estadoSync: 'pendiente_sincronizacion',
      fotoPaths: copiedPhotos,
      audioPath: copiedAudio,
    );
    final rows = await list();
    await saveAll([...rows, row]);
    return row;
  }

  Future<void> update(OfflineEmergency row) async {
    final rows = await list();
    await saveAll(rows.map((e) => e.offlineSyncId == row.offlineSyncId ? row : e).toList());
  }

  static String _extension(String path, String fallback) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx == path.length - 1) return fallback;
    final ext = path.substring(idx);
    return ext.length > 8 ? fallback : ext;
  }
}
