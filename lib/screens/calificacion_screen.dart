// flutter-app/lib/screens/calificacion_screen.dart
// Pantalla de calificación al finalizar el servicio
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CalificacionScreen extends StatefulWidget {
  final String incidenteId;
  final String nombreTaller;
  const CalificacionScreen({super.key, required this.incidenteId, required this.nombreTaller});
  @override
  State<CalificacionScreen> createState() => _CalificacionScreenState();
}

class _CalificacionScreenState extends State<CalificacionScreen> {
  int _estrellas = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;
  final _api = ApiService();

  Future<void> _enviar() async {
    if (_estrellas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 estrella')),
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      await _api.calificarServicio(
        widget.incidenteId,
        _estrellas,
        _comentarioCtrl.text,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE24B4A),
        foregroundColor: Colors.white,
        title: const Text('Calificar servicio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3DE), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF3B6D11), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('¡Servicio completado!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('¿Cómo fue tu experiencia con ${widget.nombreTaller}?',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),

          // Estrellas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _estrellas = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _estrellas ? Icons.star : Icons.star_border,
                  color: const Color(0xFFEF9F27),
                  size: 42,
                ),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Text(
            _estrellas == 0 ? 'Toca para calificar'
              : _estrellas == 1 ? 'Muy malo'
              : _estrellas == 2 ? 'Malo'
              : _estrellas == 3 ? 'Regular'
              : _estrellas == 4 ? 'Bueno'
              : 'Excelente',
            style: TextStyle(
              fontSize: 14,
              color: _estrellas == 0 ? Colors.grey : const Color(0xFFEF9F27),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Comentario
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _comentarioCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe un comentario (opcional)...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE24B4A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _enviando
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enviar calificación',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
          ),
        ]),
      ),
    );
  }
}
