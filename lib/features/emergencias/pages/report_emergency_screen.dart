import 'package:flutter/material.dart';
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
  final _api = EmergenciesApi();
  final _vehicleApi = VehicleApi();
  final _descripcionCtrl = TextEditingController();
  final _picker = ImagePicker();
  List<VehicleOption> _vehiculos = const [];
  String? _vehiculoIdSelected;
  bool _loadingVehiculos = true;
  String _vehiculosError = '';
  XFile? _image;
  Position? _position;
  bool _loading = false;

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
        await _api.uploadImage(incidenteId: incidenteId, image: _image!);
      }

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
