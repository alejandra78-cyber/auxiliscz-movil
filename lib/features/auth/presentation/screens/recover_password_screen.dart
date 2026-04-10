import 'package:flutter/material.dart';

import '../../data/auth_api.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _api = AuthApi();
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _request() async {
    setState(() => _loading = true);
    try {
      final token = await _api.requestRecoveryToken(_emailCtrl.text.trim());
      if (!mounted) return;
      if (token != null && token.isNotEmpty) _tokenCtrl.text = token;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token solicitado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      await _api.resetPassword(token: _tokenCtrl.text.trim(), newPassword: _newPasswordCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña restablecida')));
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
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1) Solicita token por correo. 2) Restablece contraseña.', style: TextStyle(color: Color(0xFF6D7890))),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loading ? null : _request, child: const Text('Solicitar token')),
          const SizedBox(height: 20),
          TextField(controller: _tokenCtrl, decoration: const InputDecoration(labelText: 'Token')),
          const SizedBox(height: 10),
          TextField(controller: _newPasswordCtrl, decoration: const InputDecoration(labelText: 'Nueva contraseña'), obscureText: true),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _reset,
              child: const Text('Restablecer contraseña'),
            ),
          ),
        ],
      ),
    );
  }
}
