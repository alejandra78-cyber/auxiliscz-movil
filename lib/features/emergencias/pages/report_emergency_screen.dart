import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  final _recorder = AudioRecorder();
  bool _isRecording = false;

  StreamSubscription<Position>? _gpsSubscription;

  List<VehicleOption> _vehiculos = const [];
  String? _vehiculoIdSelected;
  bool _loadingVehiculos = true;
  String _vehiculosError = '';
  XFile? _image;
  XFile? _audio;
  Position? _position;
  bool _loading = false;
  bool _trackingGps = false;
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

  Future<void> _checkLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS desactivado');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado');
    }
  }

  Future<void> _startRealtimeLocation() async {
    await _checkLocationPermission();

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    setState(() {
      _position = current;
      _trackingGps = true;
    });

    await _gpsSubscription?.cancel();

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
  }

  Future<void> _stopRealtimeLocation() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    if (!mounted) return;
    setState(() => _trackingGps = false);
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image != null) setState(() => _image = image);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        if (path != null) {
          _audio = XFile(path);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio grabado correctamente')),
      );
      return;
    }

    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw Exception('Permiso de micrófono denegado');
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/emergencia_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() => _isRecording = true);
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
      if (_position == null) {
        await _startRealtimeLocation();
      }

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

      await _stopRealtimeLocation();

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.emergenciaStatus,
        arguments: incidenteId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _descripcionCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsText = _position == null
        ? 'Sin ubicación todavía'
        : '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}';

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
                      Text(
                        'Datos de la emergencia',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _vehiculosError,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
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
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.vehiculoRegister,
                          ),
                          icon: const Icon(Icons.directions_car),
                          label: const Text('Registrar vehículo'),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _vehiculoIdSelected,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vehículo (placa)',
                          ),
                          items: _vehiculos
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v.id,
                                  child: Text(v.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _vehiculoIdSelected = value),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _tipoSelected,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de incidente',
                          ),
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
          TextField(
            controller: _descripcionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción del problema',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    try {
                      if (_trackingGps) {
                        await _stopRealtimeLocation();
                      } else {
                        await _startRealtimeLocation();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ubicación en tiempo real activada'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
            icon: Icon(_trackingGps ? Icons.gps_fixed : Icons.gps_not_fixed),
            label: Text(
              _trackingGps
                  ? 'Detener ubicación en tiempo real'
                  : 'Enviar ubicación en tiempo real',
            ),
          ),
          Text('Ubicación actual: $gpsText'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickImage,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Adjuntar foto del vehículo'),
          ),
          if (_image != null) Text('Foto seleccionada: ${_image!.name}'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    try {
                      await _toggleRecording();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(
              _isRecording
                  ? 'Detener grabación'
                  : 'Grabar audio describiendo el problema',
            ),
          ),
          if (_audio != null) const Text('Audio grabado listo para enviar'),
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
