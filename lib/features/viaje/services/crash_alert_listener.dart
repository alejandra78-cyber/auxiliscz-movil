import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'crash_detection_service.dart';

/// NavigatorKey global para poder mostrar el pop-up de accidente
/// desde cualquier pantalla (el evento llega del aislado del servicio).
final GlobalKey<NavigatorState> crashNavigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<int> _segundosRestantes = ValueNotifier(0);
bool _dialogoAbierto = false;

/// Registra el listener de eventos del Foreground Service.
/// Llamar una sola vez en main(), después de initCommunicationPort().
void initCrashAlertUi() {
  FlutterForegroundTask.addTaskDataCallback(_onTaskData);
}

void _onTaskData(Object data) {
  if (data is! Map) return;
  final event = data['event'];

  switch (event) {
    case kEventoChoqueDetectado:
      _segundosRestantes.value = (data['restantes'] as num?)?.toInt() ?? 15;
      _mostrarDialogoAccidente();
      break;
    case kEventoCuentaRegresiva:
      _segundosRestantes.value = (data['restantes'] as num?)?.toInt() ?? 0;
      break;
    case kEventoCancelado:
      _cerrarDialogo();
      break;
    case kEventoReportado:
      _cerrarDialogo();
      _mostrarResultado(
        titulo: '✅ Accidente reportado',
        mensaje:
            'Se creó tu solicitud de emergencia y se notificó a los talleres '
            'cercanos.'
            '${((data['contactos_notificados'] as num?)?.toInt() ?? 0) > 0 ? '\nTus contactos de emergencia recibieron tu ubicación.' : ''}',
      );
      break;
    case kEventoReporteFallo:
      _cerrarDialogo();
      _mostrarResultado(
        titulo: '⚠️ No se pudo reportar',
        mensaje:
            'Ocurrió un error al reportar el accidente automáticamente. '
            'Reporta manualmente desde "Reportar emergencia".\n\n${data['error'] ?? ''}',
      );
      break;
  }
}

void _mostrarDialogoAccidente() {
  final context = crashNavigatorKey.currentContext;
  if (context == null || _dialogoAbierto) return;
  _dialogoAbierto = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: const Row(
          children: [
            Icon(Icons.car_crash, color: Colors.red, size: 32),
            SizedBox(width: 10),
            Expanded(child: Text('¿Tuviste un accidente?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Detectamos un impacto fuerte. Si no respondes, reportaremos '
              'el accidente y avisaremos a tus contactos de emergencia.',
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<int>(
              valueListenable: _segundosRestantes,
              builder: (_, seg, __) => Column(
                children: [
                  Text(
                    '$seg',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.red,
                    ),
                  ),
                  LinearProgressIndicator(
                    value: seg / 15.0,
                    color: Colors.red,
                    backgroundColor: Colors.red.shade100,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                CrashDetectionService.confirmarEstoyBien();
                // El aislado responderá con kEventoCancelado y cerramos ahí,
                // pero cerramos ya para respuesta inmediata.
                _cerrarDialogo();
              },
              child: const Text(
                'ESTOY BIEN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  ).whenComplete(() => _dialogoAbierto = false);
}

void _cerrarDialogo() {
  if (!_dialogoAbierto) return;
  final nav = crashNavigatorKey.currentState;
  if (nav != null && nav.canPop()) nav.pop();
  _dialogoAbierto = false;
}

void _mostrarResultado({required String titulo, required String mensaje}) {
  final context = crashNavigatorKey.currentContext;
  if (context == null) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
