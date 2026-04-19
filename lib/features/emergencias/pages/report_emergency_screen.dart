import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../routes/app_routes.dart';
import '../services/emergencias_api.dart';
import '../../vehiculos/services/vehiculos_api.dart';
import '../../../shared/theme/app_theme.dart';

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
  List<VehicleOption> _vehiculos = const [];
  String? _vehiculoIdSelected;
  bool _loadingVehiculos = true;
  String _vehiculosError = '';
  XFile? _image;
  XFile? _audio;
  Position? _position;
  bool _loading = false;
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
      setState(() {
        _vehiculosError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingVehiculos = false);
      }
    }
  }

  Future<void> _getLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS desactivado');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado');
    }
    _position = await Geolocator.getCurrentPosition();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() => _image = image);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'webm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    XFile? audio;
    if (file.bytes != null) {
      audio = XFile.fromData(file.bytes!, name: file.name, mimeType: 'audio/*');
    } else if (file.path != null && file.path!.isNotEmpty) {
      audio = XFile(file.path!);
    }
    if (audio != null) {
      setState(() => _audio = audio);
    }
  }

  Future<void> _submit() async {
    if (_vehiculoIdSelected == null || _vehiculoIdSelected!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un vehículo para continuar')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      _position ??= await Geolocator.getCurrentPosition();
      final incidenteId = await _api.reportEmergency(
        vehiculoId: _vehiculoIdSelected!,
        tipo: _tipoSelected,
        lat: _position!.latitude,
        lng: _position!.longitude,
        descripcion: _descripcionCtrl.text.trim(),
        foto: _image,
        audio: _audio,
      );

      await _api.sendGps(
        incidenteId: incidenteId,
        lat: _position!.latitude,
        lng: _position!.longitude,
      );

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: incidenteId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar emergencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emergency_share, color: AppColors.accent),
                      SizedBox(width: 8),
                      Text('Datos de la emergencia', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                            if (value != null) {
                              setState(() => _tipoSelected = value);
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _descripcionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _getLocation, child: const Text('Obtener ubicación GPS')),
          if (_position != null)
            Text('Ubicación: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _pickImage, child: const Text('Tomar/Cargar imagen')),
          if (_image != null) Text('Imagen seleccionada: ${_image!.name}'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _pickAudio, child: const Text('Cargar audio')),
          if (_audio != null) Text('Audio seleccionado: ${_audio!.name}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: Text(_loading ? 'Enviando...' : 'Enviar emergencia'),
          ),
        ],
      ),
    );
  }
}
