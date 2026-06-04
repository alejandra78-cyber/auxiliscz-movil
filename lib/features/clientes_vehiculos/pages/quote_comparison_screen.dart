import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../emergencias/services/emergencias_api.dart';

class QuoteComparisonScreen extends StatefulWidget {
  const QuoteComparisonScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<QuoteComparisonScreen> createState() => _QuoteComparisonScreenState();
}

class _QuoteComparisonScreenState extends State<QuoteComparisonScreen> {
  final _api = EmergenciesApi();

  bool _loading = true;
  bool _sending = false;
  String _error = '';
  Map<String, dynamic>? _estado;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      final map = _asMap(item);
      if (map != null) rows.add(map);
    }
    return rows;
  }

  String _estadoCotizacion(Map<String, dynamic> cotizacion) {
    return (cotizacion['estado'] ?? '').toString().trim().toLowerCase();
  }

  bool _puedeResponder(Map<String, dynamic> cotizacion) {
    final estado = _estadoCotizacion(cotizacion);
    return estado == 'enviada' || estado == 'emitida' || estado == 'pendiente';
  }

  List<Map<String, dynamic>> get _cotizaciones {
    final rows = _asMapList(_estado?['cotizaciones_disponibles']);
    if (rows.isNotEmpty) return rows;
    final actual = _asMap(_estado?['cotizacion_actual']);
    return actual == null ? const [] : [actual];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await _api.getEmergencyStatus(widget.incidenteId);
      if (!mounted) return;
      setState(() => _estado = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _responder(Map<String, dynamic> cotizacion, bool aceptar) async {
    final id = (cotizacion['id'] ?? '').toString().trim();
    if (id.isEmpty || _sending) return;

    final obsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(aceptar ? 'Aceptar cotización' : 'Rechazar cotización'),
        content: TextField(
          controller: obsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: !aceptar
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(aceptar ? 'Aceptar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sending = true);
    try {
      if (aceptar) {
        await _api.acceptQuote(id, observaciones: obsCtrl.text.trim());
      } else {
        await _api.rejectQuote(id, observaciones: obsCtrl.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aceptar
                ? 'Cotización aceptada correctamente'
                : 'Cotización rechazada correctamente',
          ),
        ),
      );
      await _load();
      if (aceptar && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _cotizacionCard(Map<String, dynamic> cotizacion) {
    final estado = _estadoCotizacion(cotizacion);
    final disponible = _puedeResponder(cotizacion);
    final taller = (cotizacion['taller_nombre'] ?? 'Taller').toString();
    final calificacion = cotizacion['taller_calificacion'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  taller,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              _EstadoCotizacionBadge(estado: estado),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: 'Monto', value: '${cotizacion['monto'] ?? '-'} Bs'),
              _InfoPill(
                label: 'Tiempo',
                value: '${cotizacion['tiempo_estimado'] ?? '-'}',
              ),
              _InfoPill(label: 'Calificación', value: '${calificacion ?? '-'}'),
            ],
          ),
          const SizedBox(height: 12),
          if ((cotizacion['detalle'] ?? '').toString().trim().isNotEmpty) ...[
            const Text('Detalle', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${cotizacion['detalle']}'),
            const SizedBox(height: 10),
          ],
          if ((cotizacion['observaciones'] ?? '').toString().trim().isNotEmpty) ...[
            const Text('Observaciones',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${cotizacion['observaciones']}'),
            const SizedBox(height: 10),
          ],
          if (disponible) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : () => _responder(cotizacion, true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _sending ? null : () => _responder(cotizacion, false),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cotizaciones = _cotizaciones;

    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Comparar cotizaciones',
              subtitle:
                  'Revisa precio, tiempo estimado y detalle de cada taller antes de elegir.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 3),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_error, style: const TextStyle(color: AppColors.danger)),
                  ],
                  if (!_loading && cotizaciones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Todavía no hay cotizaciones para esta solicitud.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  if (cotizaciones.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${cotizaciones.length} cotización(es) recibida(s)',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...cotizaciones.map(_cotizacionCard),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EstadoCotizacionBadge extends StatelessWidget {
  const _EstadoCotizacionBadge({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'aceptada' => AppColors.success,
      'rechazada' => AppColors.danger,
      'vencida' => AppColors.textMuted,
      _ => AppColors.primary,
    };
    final label = switch (estado) {
      'aceptada' => 'Aceptada',
      'rechazada' => 'Rechazada',
      'vencida' => 'Vencida',
      _ => 'Disponible',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
