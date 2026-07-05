import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Contacto de emergencia al que se avisa si se detecta un accidente.
class ContactoEmergencia {
  const ContactoEmergencia({
    required this.nombre,
    this.telefono = '',
    this.email = '',
  });

  final String nombre;
  final String telefono;
  final String email;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
      };

  factory ContactoEmergencia.fromJson(Map<String, dynamic> json) =>
      ContactoEmergencia(
        nombre: (json['nombre'] ?? '').toString(),
        telefono: (json['telefono'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
      );
}

/// Persistencia de contactos de emergencia en SharedPreferences (máx. 3).
/// La clave es leída también desde el aislado del Foreground Service.
class EmergencyContactsStorage {
  static const prefsKey = 'contactos_emergencia';
  static const maxContactos = 3;

  static Future<List<ContactoEmergencia>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((e) => ContactoEmergencia.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardar(List<ContactoEmergencia> contactos) async {
    final prefs = await SharedPreferences.getInstance();
    final recortados = contactos.take(maxContactos).toList();
    await prefs.setString(
      prefsKey,
      jsonEncode(recortados.map((c) => c.toJson()).toList()),
    );
  }
}
