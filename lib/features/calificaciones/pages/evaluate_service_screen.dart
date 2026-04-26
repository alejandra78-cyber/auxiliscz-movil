import 'package:flutter/material.dart';

import '../../emergencias/services/emergencias_api.dart';

class EvaluateServiceScreen extends StatefulWidget {
  const EvaluateServiceScreen({super.key});

  @override
  State<EvaluateServiceScreen> createState() => _EvaluateServiceScreenState();
}

class _EvaluateServiceScreenState extends State<EvaluateServiceScreen> {
  final _api = EmergenciesApi();
  final _comentarioCtrl = TextEditingController();

  List<Map<String, dynamic>> _solicitudes = [];
  String? _incidenteId;
  int _estrellas = 5;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    try {
      final data = await _api.getTrackRequests();

      if (!mounted) return;

      setState(() {
        _solicitudes = data;
        _incidenteId =
            data.isNotEmpty ? data.first['incidente_id']?.toString() : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _enviarEvaluacion() async {
    if (_incidenteId == null || _incidenteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay solicitud seleccionada')),
      );
      return;
    }

    try {
      final res = await _api.evaluateService(
        incidenteId: _incidenteId!,
        estrellas: _estrellas,
        comentario: _comentarioCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje']?.toString() ?? 'Evaluación enviada'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Evaluar servicio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _error != null
            ? Center(
                child: Text(
                  'Error cargando solicitudes:\n$_error',
                  textAlign: TextAlign.center,
                ),
              )
            : _solicitudes.isEmpty
                ? const Center(
                    child: Text('No tienes solicitudes para evaluar'),
                  )
                : ListView(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _incidenteId,
                        decoration: const InputDecoration(
                          labelText: 'Solicitud',
                          border: OutlineInputBorder(),
                        ),
                        items: _solicitudes.map((s) {
                          final id = s['incidente_id']?.toString() ?? '';
                          final codigo =
                              s['codigo_solicitud']?.toString() ?? id;
                          return DropdownMenuItem(
                            value: id,
                            child: Text(codigo),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _incidenteId = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _estrellas,
                        decoration: const InputDecoration(
                          labelText: 'Calificación',
                          border: OutlineInputBorder(),
                        ),
                        items: [1, 2, 3, 4, 5]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e estrellas'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _estrellas = v ?? 5),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _comentarioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comentario',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _enviarEvaluacion,
                        icon: const Icon(Icons.star),
                        label: const Text('Enviar evaluación'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
