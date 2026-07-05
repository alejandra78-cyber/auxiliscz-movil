import 'package:flutter/material.dart';

import '../services/emergency_contacts.dart';

/// Pantalla para gestionar hasta 3 contactos de emergencia.
/// Si se detecta un accidente y el usuario no responde, se les avisa
/// por email con el enlace de ubicación.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<ContactoEmergencia> _contactos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final contactos = await EmergencyContactsStorage.cargar();
    if (!mounted) return;
    setState(() {
      _contactos = contactos;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    await EmergencyContactsStorage.guardar(_contactos);
  }

  Future<void> _agregarOEditar({ContactoEmergencia? existente, int? index}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final telefonoCtrl = TextEditingController(text: existente?.telefono ?? '');
    final emailCtrl = TextEditingController(text: existente?.email ?? '');

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existente == null ? 'Nuevo contacto' : 'Editar contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'El aviso de accidente se envía por email',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado == true) {
      final contacto = ContactoEmergencia(
        nombre: nombreCtrl.text.trim(),
        telefono: telefonoCtrl.text.trim(),
        email: emailCtrl.text.trim(),
      );
      setState(() {
        if (index != null) {
          _contactos[index] = contacto;
        } else {
          _contactos.add(contacto);
        }
      });
      await _guardar();
    }

    nombreCtrl.dispose();
    telefonoCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _eliminar(int index) async {
    setState(() => _contactos.removeAt(index));
    await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Si el Modo Viaje detecta un choque y no confirmas que '
                      'estás bien en 15 segundos, avisaremos a estas personas '
                      'con tu ubicación exacta.',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_contactos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Aún no registraste contactos de emergencia'),
                    ),
                  ),
                ..._contactos.asMap().entries.map(
                      (e) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.contact_emergency),
                          title: Text(e.value.nombre),
                          subtitle: Text(
                            [
                              if (e.value.telefono.isNotEmpty) e.value.telefono,
                              if (e.value.email.isNotEmpty) e.value.email,
                            ].join(' · '),
                          ),
                          onTap: () =>
                              _agregarOEditar(existente: e.value, index: e.key),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _eliminar(e.key),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
      floatingActionButton:
          _contactos.length < EmergencyContactsStorage.maxContactos
              ? FloatingActionButton.extended(
                  onPressed: () => _agregarOEditar(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Agregar contacto'),
                )
              : null,
    );
  }
}
