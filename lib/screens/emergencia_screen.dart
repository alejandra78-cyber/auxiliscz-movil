// flutter-app/lib/screens/emergencia_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import '../services/api_service.dart';
import '../widgets/estado_incidente_widget.dart';

class EmergenciaScreen extends StatefulWidget {
  const EmergenciaScreen({super.key});
  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  final _descripcionCtrl = TextEditingController();
  final _record = AudioRecorder();
  final _picker = ImagePicker();
  final _api = ApiService();

  Position? _posicion;
  XFile? _foto;
  String? _rutaAudio;
  bool _grabando = false;
  bool _enviando = false;
  String? _incidenteId;
  String _estado = '';

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;
    _posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {});
  }

  Future<void> _tomarFoto() async {
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (img != null) setState(() => _foto = img);
  }

  Future<void> _toggleGrabacion() async {
    if (_grabando) {
      _rutaAudio = await _record.stop();
      setState(() => _grabando = false);
    } else {
      if (await _record.hasPermission()) {
        await _record.start(
          const RecordConfig(),
          path: '/tmp/audio_emergencia.webm',
        );
        setState(() => _grabando = true);
      }
    }
  }

  Future<void> _enviarEmergencia() async {
    if (_posicion == null) {
      _mostrarError('No se pudo obtener tu ubicación. Activa el GPS.');
      return;
    }
    setState(() => _enviando = true);

    try {
      final resultado = await _api.crearIncidente(
        vehiculoId: 'vehiculo-demo-id',
        lat: _posicion!.latitude,
        lng: _posicion!.longitude,
        descripcion: _descripcionCtrl.text,
        foto: _foto,
        audioPath: _rutaAudio,
      );
      setState(() {
        _incidenteId = resultado['incidente_id'];
        _estado = 'Buscando asistencia...';
      });
      _iniciarSeguimiento();
    } catch (e) {
      _mostrarError('Error al enviar: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _iniciarSeguimiento() {
    // Polling cada 5 segundos para actualizar estado
    Stream.periodic(const Duration(seconds: 5)).listen((_) async {
      if (_incidenteId == null) return;
      final datos = await _api.obtenerIncidente(_incidenteId!);
      setState(() => _estado = datos['estado'] ?? '');
      if (_estado == 'atendido') {
        // Navegar a pantalla de calificación
      }
    });
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_incidenteId != null) {
      return EstadoIncidenteWidget(
        incidenteId: _incidenteId!,
        estado: _estado,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE24B4A),
        foregroundColor: Colors.white,
        title: const Text('AuxilioSCZ', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Botón SOS
          GestureDetector(
            onTap: _enviando ? null : _enviarEmergencia,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _enviando ? Colors.grey : const Color(0xFFE24B4A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Column(children: [
                        Icon(Icons.emergency_share, color: Colors.white, size: 40),
                        SizedBox(height: 8),
                        Text('SOLICITAR EMERGENCIA',
                            style: TextStyle(color: Colors.white, fontSize: 18,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ]),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Ubicación
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.location_on,
                  color: _posicion != null ? Colors.green : Colors.grey),
              title: Text(_posicion != null
                  ? 'Ubicación detectada'
                  : 'Obteniendo ubicación...'),
              subtitle: _posicion != null
                  ? Text('${_posicion!.latitude.toStringAsFixed(4)}, ${_posicion!.longitude.toStringAsFixed(4)}')
                  : null,
              trailing: TextButton(onPressed: _obtenerUbicacion, child: const Text('Actualizar')),
            ),
          ),

          const SizedBox(height: 12),

          // Adjuntar foto
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE24B4A)),
                title: const Text('Foto del vehículo'),
                subtitle: _foto != null ? const Text('Foto adjunta ✓') : null,
                trailing: TextButton(onPressed: _tomarFoto, child: const Text('Tomar foto')),
              ),
              if (_foto != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_foto!.path), height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          // Grabar audio
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(_grabando ? Icons.stop : Icons.mic,
                  color: _grabando ? Colors.red : const Color(0xFFE24B4A)),
              title: Text(_grabando ? 'Grabando...' : 'Describir por audio'),
              subtitle: _rutaAudio != null && !_grabando ? const Text('Audio grabado ✓') : null,
              trailing: ElevatedButton(
                onPressed: _toggleGrabacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _grabando ? Colors.red : const Color(0xFFE24B4A),
                ),
                child: Text(_grabando ? 'Detener' : 'Grabar',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Texto adicional
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _descripcionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe el problema (opcional)...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
