import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  _StatusStyle _styleFor(String raw) {
    final s = raw.trim().toLowerCase().replaceAll(' ', '_');
    // Primero respetamos etiquetas amigables de flujo cliente.
    if (s == 'solicitud_enviada') {
      return const _StatusStyle('Solicitud enviada', Color(0xFFFEF3C7), AppColors.warning);
    }
    if (s == 'analizando_emergencia') {
      return const _StatusStyle('Analizando emergencia', Color(0xFFE0E7FF), AppColors.info);
    }
    if (s == 'buscando_asistencia') {
      return const _StatusStyle('Buscando asistencia', Color(0xFFE0E7FF), AppColors.info);
    }
    if (s == 'taller_asignado') {
      return const _StatusStyle('Taller asignado', Color(0xFFDBEAFE), AppColors.primary);
    }
    if (s == 'tecnico_asignado') {
      return const _StatusStyle('Técnico asignado', Color(0xFFDBEAFE), AppColors.primary);
    }
    if (s == 'tecnico_en_camino') {
      return const _StatusStyle('Técnico en camino', Color(0xFFDBEAFE), AppColors.primary);
    }
    if (s == 'tecnico_en_el_lugar') {
      return const _StatusStyle('Técnico en el lugar', Color(0xFFDBEAFE), AppColors.primary);
    }
    if (s == 'diagnostico_completado') {
      return const _StatusStyle('Diagnóstico completado', Color(0xFFE0E7FF), AppColors.info);
    }
    if (s == 'cotizacion_disponible') {
      return const _StatusStyle('Cotización disponible', Color(0xFFE0E7FF), AppColors.info);
    }
    if (s == 'pago_pendiente') {
      return const _StatusStyle('Pago pendiente', Color(0xFFFEF3C7), AppColors.warning);
    }
    if (s == 'servicio_completado') {
      return const _StatusStyle('Servicio completado', Color(0xFFDCFCE7), AppColors.success);
    }
    if (s == 'solicitud_cancelada') {
      return const _StatusStyle('Solicitud cancelada', Color(0xFFFEE2E2), AppColors.danger);
    }

    // Luego, mapeo por estados internos backend.
    if (s.contains('cancel')) {
      return const _StatusStyle('Cancelado', Color(0xFFFEE2E2), AppColors.danger);
    }
    if (s.contains('final') || s.contains('complet') || s.contains('pagado') || s.contains('atendido')) {
      return const _StatusStyle('Completado', Color(0xFFDCFCE7), AppColors.success);
    }
    if (s.contains('proceso') || s.contains('camino') || s.contains('asign')) {
      return const _StatusStyle('En curso', Color(0xFFDBEAFE), AppColors.primary);
    }
    if (s.contains('pendiente') || s.contains('revision') || s.contains('esperando')) {
      return const _StatusStyle('Pendiente', Color(0xFFFEF3C7), AppColors.warning);
    }
    return _StatusStyle(raw.isEmpty ? 'Sin estado' : raw, const Color(0xFFE2E8F0), AppColors.info);
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);

  final String label;
  final Color bg;
  final Color fg;
}

