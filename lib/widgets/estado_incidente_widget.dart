import 'package:flutter/material.dart';

class EstadoIncidenteWidget extends StatelessWidget {
  final String estado;
  final String? incidenteId;
  final VoidCallback? onActualizar;

  const EstadoIncidenteWidget({
    super.key,
    required this.estado,
    this.incidenteId,
    this.onActualizar,
  });

  Color _getEstadoColor() {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'en_proceso':
        return Colors.blue;
      case 'resuelto':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon() {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Icons.schedule;
      case 'en_proceso':
        return Icons.build;
      case 'resuelto':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getEstadoTexto() {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'en_proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _getEstadoIcon(),
                  color: _getEstadoColor(),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado del Incidente',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _getEstadoTexto(),
                        style: TextStyle(
                          color: _getEstadoColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (incidenteId != null) ...[
              const SizedBox(height: 12),
              Text(
                'ID: $incidenteId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onActualizar != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onActualizar,
                child: const Text('Actualizar Estado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
