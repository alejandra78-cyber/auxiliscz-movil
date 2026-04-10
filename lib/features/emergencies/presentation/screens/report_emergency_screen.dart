import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/emergencies_api.dart';
import '../../../../shared/theme/app_theme.dart';

class ReportEmergencyScreen extends StatefulWidget {
  const ReportEmergencyScreen({super.key});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  final _api = EmergenciesApi();
  final _vehiculoIdCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  Position? _position;
  bool _loading = false;

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

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      _position ??= await Geolocator.getCurrentPosition();
      final incidenteId = await _api.reportEmergency(
        vehiculoId: _vehiculoIdCtrl.text.trim(),
        lat: _position!.latitude,
        lng: _position!.longitude,
        descripcion: _descripcionCtrl.text.trim(),
      );

      await _api.sendGps(
        incidenteId: incidenteId,
        lat: _position!.latitude,
        lng: _position!.longitude,
      );

      if (_image != null) {
        await _api.uploadImage(incidenteId: incidenteId, imagePath: _image!.path);
      }

      if (!mounted) return;
      Navigator.pushNamed(context, '/emergency-status', arguments: incidenteId);
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
                  TextField(controller: _vehiculoIdCtrl, decoration: const InputDecoration(labelText: 'ID vehículo')),
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
