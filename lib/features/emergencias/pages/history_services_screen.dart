import 'package:flutter/material.dart';

import '../../../shared/widgets/section_card.dart';
import '../services/emergencias_api.dart';

class HistoryServicesScreen extends StatefulWidget {
  const HistoryServicesScreen({super.key});

  @override
  State<HistoryServicesScreen> createState() => _HistoryServicesScreenState();
}

class _HistoryServicesScreenState extends State<HistoryServicesScreen> {
  final _api = EmergenciesApi();
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final rows = await _api.getHistoryServices();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CU25 · Historial de servicios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          if (!_loading && _error.isEmpty && _rows.isEmpty)
            const SectionCard(title: 'Sin historial', child: Text('Aún no tienes servicios finalizados o cancelados.')),
          ..._rows.map((row) {
            final veh = row['vehiculo'] as Map<String, dynamic>?;
            final eval = row['evaluacion'] as Map<String, dynamic>?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                title: '${row['codigo_solicitud'] ?? 'Solicitud'} · ${row['estado_final'] ?? '-'}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fecha: ${row['fecha'] ?? '-'}'),
                    Text('Vehículo: ${veh?['placa'] ?? '-'}'),
                    Text('Tipo: ${row['tipo_problema'] ?? '-'}'),
                    Text('Monto pagado: ${row['monto_pagado'] ?? '-'}'),
                    Text('Trabajo: ${row['trabajo_realizado'] ?? '-'}'),
                    Text('Evaluación: ${eval?['calificacion'] ?? '-'}'),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
