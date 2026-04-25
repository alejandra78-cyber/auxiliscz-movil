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

