import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../services/auth_api.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _api = AuthApi();
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loadingRequest = false;
  bool _loadingReset = false;
  bool _showResetForm = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialToken ?? '').trim();
    if (initial.isNotEmpty) {
      _tokenCtrl.text = initial;
      _showResetForm = true;
    }
  }

  String _extractTokenFromInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null) {
      final fromQuery = uri.queryParameters['reset_token']?.trim() ?? '';
      if (fromQuery.isNotEmpty) return fromQuery;
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last == 'recover-password') {
        final tokenCandidate = uri.fragment.trim();
        if (tokenCandidate.isNotEmpty) return tokenCandidate;
      }
    }
    return value;
  }

  String? _emailValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'El correo es obligatorio';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Ingresa un correo válido';
    return null;
  }

  String? _tokenValidator(String? value) {
    final token = _extractTokenFromInput(value ?? '');
    if (token.isEmpty) return 'Debes ingresar el token o pegar el enlace';
    return null;
  }

  String? _passwordValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'La nueva contraseña es obligatoria';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Confirma la nueva contraseña';
    if (v != _newPasswordCtrl.text.trim()) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _request() async {
    final form = _requestFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loadingRequest = true);
    try {
      await _api.requestRecoveryToken(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si el correo existe, enviamos un enlace de recuperación.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingRequest = false);
    }
  }

  Future<void> _reset() async {
    final form = _resetFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loadingReset = true);
    try {
      final cleanToken = _extractTokenFromInput(_tokenCtrl.text);
      await _api.validateResetToken(cleanToken);
      await _api.resetPassword(
        token: cleanToken,
        newPassword: _newPasswordCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingReset = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Solicita el enlace desde tu correo y luego establece una nueva contraseña.',
              style: TextStyle(color: Color(0xFF6D7890)),
            ),
            const SizedBox(height: 16),
            Form(
              key: _requestFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadingRequest ? null : _request,
                      child: Text(_loadingRequest ? 'Enviando...' : 'Enviar enlace de recuperación'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadingReset
                  ? null
                  : () => setState(() => _showResetForm = !_showResetForm),
              icon: Icon(_showResetForm ? Icons.expand_less : Icons.expand_more),
              label: Text(_showResetForm ? 'Ocultar cambio de contraseña' : 'Ya tengo token / enlace'),
            ),
            if (_showResetForm) ...[
              const SizedBox(height: 10),
              Form(
                key: _resetFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tokenCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Token o enlace completo',
                        helperText: 'Puedes pegar el token o todo el enlace recibido por correo',
                      ),
                      validator: _tokenValidator,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: _confirmPasswordValidator,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loadingReset ? null : _reset,
                        child: Text(_loadingReset ? 'Actualizando...' : 'Actualizar contraseña'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
