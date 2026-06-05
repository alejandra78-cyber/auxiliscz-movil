import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../services/emergencias_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = EmergenciesApi();
  List<Map<String, dynamic>> _notifications = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final rows = await _api.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openNotification(Map<String, dynamic> n) {
    final tipo = (n['tipo'] ?? '').toString();
    final id = (n['incidente_id'] ?? n['solicitud_id'] ?? '').toString().trim();
    if (id.isEmpty) {
      Navigator.pushNamed(context, AppRoutes.home);
      return;
    }
    if (tipo.contains('chat') || tipo.contains('mensaje')) {
      Navigator.pushNamed(context, AppRoutes.solicitudChat, arguments: id);
    } else if (tipo.contains('cotizacion')) {
      Navigator.pushNamed(context, AppRoutes.cotizacionesComparar, arguments: id);
    } else if (tipo.contains('seguimiento')) {
      Navigator.pushNamed(context, AppRoutes.tecnicoLocation, arguments: id);
    } else {
      Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: id);
    }
  }

  String _formatFecha(String? iso) {
    final parsed = DateTime.tryParse((iso ?? '').toString());
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(onPressed: _loadNotifications, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Bandeja',
            subtitle: 'Toca una notificación para abrir la pantalla relacionada.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error.isNotEmpty)
                  Text(_error, style: const TextStyle(color: AppColors.danger))
                else if (_notifications.isEmpty)
                  const Text(
                    'No tienes notificaciones todavía.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else
                  ..._notifications.map(
                    (n) => Card(
                      elevation: 0,
                      color: (n['estado'] ?? '') == 'no_leida'
                          ? const Color(0xFFEAF0FF)
                          : Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: Text((n['titulo'] ?? 'Notificación').toString()),
                        subtitle: Text(
                          '${n['mensaje'] ?? ''}\n${n['tipo'] ?? ''} · ${_formatFecha(n['creada_en']?.toString())}',
                        ),
                        isThreeLine: true,
                        onTap: () => _openNotification(n),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
