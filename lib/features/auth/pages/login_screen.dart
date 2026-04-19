import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../services/auth_api.dart';
import '../../../shared/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = AuthApi();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _api.login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('AuxilioSCZ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  const Text('Inicia sesión para continuar', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Color(0xFF101828)),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Color(0xFF344054)),
                      hintStyle: TextStyle(color: Color(0xFF667085)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    style: const TextStyle(color: Color(0xFF101828)),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: TextStyle(color: Color(0xFF344054)),
                      hintStyle: TextStyle(color: Color(0xFF667085)),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(
                        _loading ? 'Ingresando...' : 'Iniciar sesión',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                    child: const Text('Crear cuenta', style: TextStyle(color: AppColors.primary)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.recover),
                    child: const Text('Recuperar contraseña', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
