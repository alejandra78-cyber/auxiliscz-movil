import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../vehiculos/services/vehiculos_api.dart';
import '../services/emergencias_api.dart';

class ReportEmergencyScreen extends StatefulWidget {
  const ReportEmergencyScreen({super.key});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  static const List<String> _tiposIncidente = [
    'bateria',
    'llanta',
    'motor',
    'choque',
    'llave',
    'otro',
    'incierto',
  ];

  final _api = EmergenciesApi();
  final _vehicleApi = VehicleApi();
  final _descripcionCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  List<VehicleOption> _vehiculos = const [];
  String? _vehiculoIdSelected;
  bool _loadingVehiculos = true;
  String _vehiculosError = '';

  final List<XFile> _images = [];
  XFile? _audio;
  Position? _position;
  bool _loading = false;
  bool _recording = false;
  String _tipoSelected = 'otro';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loadingVehiculos = true;
      _vehiculosError = '';
    });
    try {
      final data = await _vehicleApi.myVehicles();
      if (!mounted) return;
      setState(() {
        _vehiculos = data;
        _vehiculoIdSelected = data.isNotEmpty ? data.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _vehiculosError = '$e');
    } finally {
      if (mounted) setState(() => _loadingVehiculos = false);
    }
  }

  Future<void> _getLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('GPS desactivado. Actívalo e inténtalo de nuevo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }

    _position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
    setState(() {});
  }

  Future<void> _requestGpsWithFeedback() async {
    try {
      await _getLocation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación GPS obtenida correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _takePhoto() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (image == null) return;
    setState(() => _images.add(image));
  }

  Future<void> _pickFromGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    setState(() => _images.addAll(images));
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _audioRecorder.stop();
      setState(() => _recording = false);
      if (path != null && path.isNotEmpty) {
        setState(() => _audio = XFile(path));
      }
      return;
    }

    final ok = await _audioRecorder.hasPermission();
    if (!ok) {
      throw Exception('Permiso de micrófono denegado');
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/emergencia_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() => _recording = true);
  }

  bool _tieneEvidencias() {
    return _images.isNotEmpty || _audio != null || _descripcionCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (_vehiculoIdSelected == null || _vehiculoIdSelected!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un vehículo para continuar')),
      );
      return;
    }
    if (!_tieneEvidencias()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta foto/audio o escribe una descripción')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      _position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final incidenteId = await _api.reportEmergency(
        vehiculoId: _vehiculoIdSelected!,
        tipo: _tipoSelected,
        lat: _position!.latitude,
        lng: _position!.longitude,
        descripcion: _descripcionCtrl.text.trim(),
        fotos: _images,
        audio: _audio,
      );

      await _api.sendGps(
        incidenteId: incidenteId,
        lat: _position!.latitude,
        lng: _position!.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergencia reportada correctamente')),
      );
      Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: incidenteId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar emergencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'CU11 · Reportar emergencia',
            subtitle: 'Paso 1: Selecciona vehículo y tipo de incidente.',
            icon: Icons.emergency_share,
            child: Column(
              children: [
                if (_loadingVehiculos)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                else if (_vehiculosError.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No se pudieron cargar tus vehículos',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 6),
                      Text(_vehiculosError, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadVehicles,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                else if (_vehiculos.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Aún no tienes vehículos registrados'),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.vehiculoRegister),
                        icon: const Icon(Icons.directions_car),
                        label: const Text('Registrar vehículo'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _vehiculoIdSelected,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Vehículo (placa)'),
                        items: _vehiculos
                            .map(
                              (v) => DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(v.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _vehiculoIdSelected = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _tipoSelected,
                        decoration: const InputDecoration(labelText: 'Tipo de incidente'),
                        items: _tiposIncidente
                            .map(
                              (tipo) => DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(tipo),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _tipoSelected = value);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Paso 2: Describe el problema',
            child: TextField(
              controller: _descripcionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción adicional (opcional)'),
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Paso 3: Ubicación y evidencias',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _requestGpsWithFeedback,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Obtener ubicación GPS'),
                ),
                if (_position != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Ubicación: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Tomar foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Elegir de galería'),
                    ),
                  ],
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final img = _images[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(img.path), width: 84, height: 84, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => setState(() => _images.removeAt(index)),
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _toggleRecord,
                  icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
                  label: Text(_recording ? 'Detener grabación' : 'Grabar audio'),
                ),
                if (_audio != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.audiotrack, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Audio: ${_audio!.name}')),
                      TextButton(
                        onPressed: () => setState(() => _audio = null),
                        child: const Text('Quitar'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Enviando...' : 'Enviar emergencia'),
          ),
        ],
      ),
    );
  }
}
