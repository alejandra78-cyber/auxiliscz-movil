import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehiculos/services/vehiculos_api.dart';

class RegisterVehicleScreen extends StatefulWidget {
  const RegisterVehicleScreen({super.key});

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _api = VehicleApi();
  final _formKey = GlobalKey<FormState>();

  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _observacionCtrl = TextEditingController();

  List<VehicleOption> _vehiculos = const [];
  bool _loadingList = true;
  bool _saving = false;
  bool _editing = false;
  String? _editingVehicleId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  String? _placaValidator(String? value) {
    final placa = (value ?? '').trim();
    if (placa.isEmpty) return 'La placa es obligatoria';
    if (placa.length < 5 || placa.length > 20) return 'La placa debe tener entre 5 y 20 caracteres';
    return null;
  }

  String? _anioValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'El año es obligatorio';
    final year = int.tryParse(raw);
    if (year == null) return 'El año debe ser numérico';
    if (year < 1950 || year > 2100) return 'Ingresa un año válido';
    return null;
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingList = true);
    try {
      final list = await _api.myVehicles(onlyActive: false);
      if (!mounted) return;
      setState(() => _vehiculos = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  void _clearForm() {
    _placaCtrl.clear();
    _marcaCtrl.clear();
    _modeloCtrl.clear();
    _anioCtrl.clear();
    _colorCtrl.clear();
    _tipoCtrl.clear();
    _observacionCtrl.clear();
    _editing = false;
    _editingVehicleId = null;
  }

  void _startEdit(VehicleOption v) {
    setState(() {
      _editing = true;
      _editingVehicleId = v.id;
      _placaCtrl.text = v.placa;
      _marcaCtrl.text = v.marca ?? '';
      _modeloCtrl.text = v.modelo ?? '';
      _anioCtrl.text = v.anio?.toString() ?? '';
      _colorCtrl.text = v.color ?? '';
      _tipoCtrl.text = v.tipo ?? '';
      _observacionCtrl.text = v.observacion ?? '';
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);
    try {
      final anio = int.parse(_anioCtrl.text.trim());
      if (_editing && _editingVehicleId != null) {
        await _api.updateVehicle(
          id: _editingVehicleId!,
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: anio,
          color: _colorCtrl.text.trim(),
          tipo: _tipoCtrl.text.trim(),
          observacion: _observacionCtrl.text.trim(),
        );
      } else {
        await _api.registerVehicle(
          placa: _placaCtrl.text.trim(),
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: anio,
          color: _colorCtrl.text.trim(),
          tipo: _tipoCtrl.text.trim(),
          observacion: _observacionCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Vehículo actualizado' : 'Vehículo registrado')),
      );
      _clearForm();
      await _loadVehicles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate(String vehicleId) async {
    setState(() => _saving = true);
    try {
      await _api.deactivateVehicle(vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehículo desactivado')),
      );
      await _loadVehicles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeactivate(VehicleOption v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar vehículo'),
        content: Text('¿Seguro que deseas desactivar ${v.placa}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
        ],
      ),
    );
    if (ok == true) {
      await _deactivate(v.id);
    }
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    _tipoCtrl.dispose();
    _observacionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis vehículos')),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: SectionCard(
                title: _editing ? 'CU10 · Editar vehículo' : 'Registrar vehículo',
                subtitle: 'Gestiona los vehículos vinculados a tu cuenta.',
                icon: Icons.directions_car_filled_outlined,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editing)
                          TextButton(
                            onPressed: _saving ? null : () => setState(_clearForm),
                            child: const Text('Cancelar edición'),
                          ),
                      ],
                    ),
                    TextFormField(
                      controller: _placaCtrl,
                      decoration: const InputDecoration(labelText: 'Placa'),
                      textCapitalization: TextCapitalization.characters,
                      validator: _placaValidator,
                      enabled: !_editing,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _marcaCtrl,
                      decoration: const InputDecoration(labelText: 'Marca'),
                      validator: (v) => _requiredValidator(v, 'La marca'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _modeloCtrl,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                      validator: (v) => _requiredValidator(v, 'El modelo'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _anioCtrl,
                      decoration: const InputDecoration(labelText: 'Año'),
                      keyboardType: TextInputType.number,
                      validator: _anioValidator,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _colorCtrl,
                      decoration: const InputDecoration(labelText: 'Color (opcional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tipoCtrl,
                      decoration: const InputDecoration(labelText: 'Tipo de vehículo (opcional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _observacionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Observación (opcional)'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: Text(_saving ? 'Guardando...' : (_editing ? 'Actualizar vehículo' : 'Registrar vehículo')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Vehículos registrados', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 8),
            if (_loadingList)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_vehiculos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Aún no tienes vehículos registrados.'),
                ),
              )
            else
              ..._vehiculos.map(
                (v) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                v.label,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                            StatusChip(status: v.activo ? 'activo' : 'inactivo'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Año: ${v.anio ?? '-'} · Color: ${v.color ?? '-'}'),
                        Text('Tipo: ${v.tipo ?? '-'}'),
                        if ((v.observacion ?? '').trim().isNotEmpty) Text('Obs: ${v.observacion}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (v.activo)
                              OutlinedButton(
                                onPressed: _saving ? null : () => _startEdit(v),
                                child: const Text('Editar'),
                              ),
                            if (v.activo)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: _saving ? null : () => _confirmDeactivate(v),
                                child: const Text('Desactivar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
