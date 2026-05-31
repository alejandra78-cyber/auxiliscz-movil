import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'emergencias_api.dart';
import 'offline_emergency_store.dart';

class EmergencySyncService {
  EmergencySyncService({
    OfflineEmergencyStore? store,
    EmergenciesApi? api,
  })  : _store = store ?? OfflineEmergencyStore(),
        _api = api ?? EmergenciesApi();

  final OfflineEmergencyStore _store;
  final EmergenciesApi _api;
  static bool _syncInProgress = false;

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> pendingCount() async {
    final rows = await _store.list();
    return rows.where((e) => e.estadoSync != 'sincronizado').length;
  }

  Future<int> syncPending() async {
    if (_syncInProgress) return 0;
    if (!await hasInternet()) return 0;
    final rows = await _store.list();
    if (!rows.any((e) => e.estadoSync != 'sincronizado')) return 0;
    _syncInProgress = true;
    var synced = 0;
    try {
      for (final row in rows.where((e) => e.estadoSync != 'sincronizado')) {
        await _store.update(row.copyWith(estadoSync: 'sincronizando', error: null));
        try {
          final incidenteId = await _api.reportEmergency(
            vehiculoId: row.vehiculoId,
            tipo: 'incierto',
            lat: row.lat,
            lng: row.lng,
            descripcion: row.descripcion,
            fotos: row.fotoPaths.map((p) => XFile(p)).toList(),
            audio: row.audioPath != null ? XFile(row.audioPath!) : null,
            offlineSyncId: row.offlineSyncId,
            fechaLocal: row.fechaLocal,
          );
          await _api.sendGps(incidenteId: incidenteId, lat: row.lat, lng: row.lng);
          await _store.update(row.copyWith(estadoSync: 'sincronizado', incidenteId: incidenteId, error: null));
          synced++;
        } catch (e) {
          await _store.update(row.copyWith(estadoSync: 'error_sincronizacion', error: e.toString()));
        }
      }
      return synced;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<OfflineEmergency> saveOfflineEmergency({
    required String vehiculoId,
    required double lat,
    required double lng,
    required String descripcion,
    required List<XFile> fotos,
    XFile? audio,
  }) {
    return _store.add(
      vehiculoId: vehiculoId,
      lat: lat,
      lng: lng,
      descripcion: descripcion,
      fotos: fotos,
      audio: audio,
    );
  }
}
