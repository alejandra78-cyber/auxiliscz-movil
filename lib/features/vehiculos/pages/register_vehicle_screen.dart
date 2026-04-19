import 'package:flutter/material.dart';

import '../services/vehiculos_api.dart';

class RegisterVehicleScreen extends StatefulWidget {
  const RegisterVehicleScreen({super.key});

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _api = VehicleApi();
  final _placa = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _color = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _api.registerVehicle(
        placa: _placa.text.trim(),
        marca: _marca.text.trim(),
        modelo: _modelo.text.trim(),
        anio: int.tryParse(_anio.text.trim()) ?? 2024,
        color: _color.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo registrado')));
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Registrar vehículo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(padding: const EdgeInsets.all(0),
          children: [
            TextField(controller: _placa, decoration: const InputDecoration(labelText: 'Placa')),
            const SizedBox(height: 10),
            TextField(controller: _marca, decoration: const InputDecoration(labelText: 'Marca')),
            const SizedBox(height: 10),
            TextField(controller: _modelo, decoration: const InputDecoration(labelText: 'Modelo')),
            const SizedBox(height: 10),
            TextField(controller: _anio, decoration: const InputDecoration(labelText: 'Año'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color')),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Guardando...' : 'Registrar vehículo'),
            ),
          ],
        ),
      ),
    );
  }
}
