import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../services/emergencias_api.dart';

class RequestChatScreen extends StatefulWidget {
  const RequestChatScreen({super.key, required this.incidenteId});

  final String incidenteId;

  @override
  State<RequestChatScreen> createState() => _RequestChatScreenState();
}

class _RequestChatScreenState extends State<RequestChatScreen> {
  final _api = EmergenciesApi();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _mensajes = const [];
  bool _loading = true;
  bool _sending = false;
  String _error = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final rows = await _api.getMessages(widget.incidenteId);
      if (!mounted) return;
      setState(() {
        _mensajes = rows;
        _error = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendMessage(widget.incidenteId, txt);
      if (!mounted) return;
      _msgCtrl.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _formatFecha(String? iso) {
    final parsed = DateTime.tryParse((iso ?? '').toString());
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat con el taller'),
        actions: [
          IconButton(
            onPressed: () => _loadMessages(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Conversación',
                  subtitle: 'Aquí puedes ver y responder los mensajes del taller.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error.isNotEmpty)
                        Text(_error, style: const TextStyle(color: AppColors.danger))
                      else if (_mensajes.isEmpty)
                        const Text(
                          'Aún no hay mensajes. Escribe al taller para iniciar la conversación.',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      else
                        ..._mensajes.map(_messageBubble),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _sending ? null : _sendMessage,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> msg) {
    final autor = (msg['autor_rol'] ?? 'usuario').toString();
    final texto = (msg['texto'] ?? '').toString();
    final creado = _formatFecha(msg['creado_en']?.toString());
    final propio = autor == 'conductor' || autor == 'cliente';
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: propio ? AppColors.primary : const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$autor${creado.isNotEmpty ? ' · $creado' : ''}',
              style: TextStyle(
                color: propio ? Colors.white70 : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              texto,
              style: TextStyle(color: propio ? Colors.white : AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
