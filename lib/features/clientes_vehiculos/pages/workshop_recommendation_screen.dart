import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../emergencias/services/emergencias_api.dart';

class WorkshopRecommendationScreen extends StatefulWidget {
  const WorkshopRecommendationScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<WorkshopRecommendationScreen> createState() =>
      _WorkshopRecommendationScreenState();
}

class _WorkshopRecommendationScreenState
    extends State<WorkshopRecommendationScreen> {
  final _api = EmergenciesApi();
  final _consultaCtrl = TextEditingController(text: '¿Qué taller me recomiendas?');
  final _speech = stt.SpeechToText();
  String _consultaRapida = '¿Qué taller me recomiendas?';

  bool _loading = false;
  bool _listening = false;
  bool _speechReady = false;
  String _error = '';
  Map<String, dynamic>? _resultado;

  final _ejemplos = const [
    '¿Qué taller me recomiendas?',
    '¿Cuál es el más barato?',
    '¿Cuál llega más rápido?',
    '¿Cuál tiene mejor calificación?',
    '¿Cuál tiene mejor relación precio y calidad?',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize();
      if (mounted) setState(() => _speechReady = ready);
    } catch (_) {
      if (mounted) setState(() => _speechReady = false);
    }
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      setState(() => _error = 'El dictado no está disponible. Puedes escribir la consulta.');
      return;
    }
    setState(() {
      _error = '';
      _listening = true;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es_BO',
        partialResults: true,
      ),
      onResult: (result) {
        setState(() => _consultaCtrl.text = result.recognizedWords);
      },
    );
  }

  Future<void> _consultar() async {
    final consulta = _consultaCtrl.text.trim();
    if (consulta.isEmpty) {
      setState(() => _error = 'Escribe o dicta una consulta.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _resultado = null;
    });
    try {
      final res = await _api.recommendQuoteByAudio(
        incidenteId: widget.incidenteId,
        consulta: consulta,
      );
      if (!mounted) return;
      setState(() => _resultado = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _ranking() {
    final raw = _resultado?['ranking'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  @override
  void dispose() {
    _speech.cancel();
    _consultaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranking = _ranking();
    final recomendado = (_resultado?['taller_recomendado'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Recomendación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Consulta por audio',
            subtitle: 'Te sugerimos una opción, pero tú decides qué cotización aceptar.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _consultaRapida,
                  decoration: const InputDecoration(
                    labelText: 'Consulta rápida',
                  ),
                  selectedItemBuilder: (context) => _ejemplos
                      .map(
                        (item) => Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      .toList(),
                  items: _ejemplos
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _consultaRapida = value;
                      _consultaCtrl.text = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _consultaCtrl,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Texto reconocido o escrito',
                    hintText: 'Ej: ¿Cuál tiene mejor relación precio y calidad?',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _consultaCtrl.clear();
                              _resultado = null;
                              _error = '';
                            }),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                    label: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _toggleSpeech,
                        icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                        label: Text(_listening ? 'Detener audio' : 'Hablar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _consultar,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(_loading ? 'Consultando...' : 'Consultar'),
                      ),
                    ),
                  ],
                ),
                if (_listening) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Escuchando tu consulta...',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_error, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          if (_resultado != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Consulta interpretada',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(label: 'Criterio', value: '${_resultado?['criterio'] ?? '-'}'),
                  if (recomendado.isNotEmpty)
                    _InfoLine(label: 'Taller recomendado', value: recomendado),
                  const SizedBox(height: 8),
                  Text(
                    '${_resultado?['motivo'] ?? '-'}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ranking de opciones disponibles',
              subtitle: ranking.isEmpty
                  ? 'Sin cotizaciones disponibles para recomendar.'
                  : 'Solo se analizan cotizaciones enviadas para esta solicitud.',
              child: Column(
                children: ranking.isEmpty
                    ? [const Text('Sin datos disponibles.')]
                    : ranking.map((row) => _RankingCard(row: row)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: Text('${row['posicion'] ?? '-'}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${row['taller'] ?? 'Taller'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('Monto', '${row['monto'] ?? '-'} Bs'),
              _Pill('Tiempo', '${row['tiempo_estimado'] ?? '-'}'),
              _Pill('Calificación', '${row['calificacion_promedio'] ?? '-'}'),
              _Pill('SLA', '${row['cumplimiento_sla'] ?? 0}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text('${row['motivo'] ?? ''}', style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
