import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
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
  bool _marking = false;
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

  Future<void> _markRead(Map<String, dynamic> n) async {
    final id = (n['id'] ?? '').toString();
    if (id.isEmpty || _marking) return;
    setState(() => _marking = true);
    try {
      await _api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        n['estado'] = 'leida';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_marking || _notifications.isEmpty) return;
    setState(() => _marking = true);
    try {
      await _api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n['estado'] = 'leida';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    await _markRead(n);
    if (!mounted) return;
    final tipo = (n['tipo'] ?? '').toString().toLowerCase();
    final id = (n['incidente_id'] ?? n['solicitud_id'] ?? '').toString().trim();
    if (id.isEmpty) {
      Navigator.pushNamed(context, AppRoutes.home);
      return;
    }
    if (tipo.contains('chat') || tipo.contains('mensaje')) {
      Navigator.pushNamed(context, AppRoutes.solicitudChat, arguments: id);
    } else if (tipo.contains('cotizacion')) {
      Navigator.pushNamed(context, AppRoutes.cotizacionesComparar, arguments: id);
    } else if (tipo.contains('seguimiento') || tipo.contains('tecnico')) {
      Navigator.pushNamed(context, AppRoutes.tecnicoLocation, arguments: id);
    } else {
      Navigator.pushNamed(context, AppRoutes.emergenciaStatus, arguments: id);
    }
  }

  String _formatFecha(String? iso) {
    final parsed = DateTime.tryParse((iso ?? '').toString());
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (date == today) return 'Hoy $hh:$mm';
    if (date == today.subtract(const Duration(days: 1))) return 'Ayer $hh:$mm';
    return '${local.day}/${local.month} $hh:$mm';
  }

  IconData _iconFor(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('cotizacion')) return Icons.request_quote_outlined;
    if (t.contains('pago')) return Icons.payments_outlined;
    if (t.contains('tecnico')) return Icons.engineering_outlined;
    if (t.contains('seguimiento')) return Icons.location_on_outlined;
    if (t.contains('chat') || t.contains('mensaje')) return Icons.chat_bubble_outline;
    return Icons.notifications_outlined;
  }

  Color _colorFor(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('pago')) return AppColors.success;
    if (t.contains('tecnico') || t.contains('seguimiento')) return AppColors.accent;
    if (t.contains('chat') || t.contains('mensaje')) return AppColors.warning;
    if (t.contains('cotizacion')) return AppColors.primary;
    return AppColors.info;
  }

  String _badgeFor(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('cotizacion')) return 'Cotización';
    if (t.contains('pago')) return 'Pago';
    if (t.contains('tecnico')) return 'Técnico';
    if (t.contains('seguimiento')) return 'Seguimiento';
    if (t.contains('chat') || t.contains('mensaje')) return 'Chat';
    return 'Sistema';
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => (n['estado'] ?? '') == 'no_leida').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(onPressed: _loadNotifications, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    unread == 0 ? 'Bandeja al día' : '$unread sin leer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: unread == 0 || _marking ? null : _markAllRead,
                  child: const Text('Marcar todas como leídas'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              _EmptyState(icon: Icons.error_outline, text: _error, color: AppColors.danger)
            else if (_notifications.isEmpty)
              const _EmptyState(
                icon: Icons.notifications_none_outlined,
                text: 'No tienes notificaciones por ahora.',
                color: AppColors.textMuted,
              )
            else
              ..._notifications.map(
                (n) => _NotificationCard(
                  item: n,
                  icon: _iconFor('${n['tipo'] ?? ''}'),
                  color: _colorFor('${n['tipo'] ?? ''}'),
                  badge: _badgeFor('${n['tipo'] ?? ''}'),
                  date: _formatFecha(n['creada_en']?.toString()),
                  onOpen: () => _openNotification(n),
                  onRead: () => _markRead(n),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.icon,
    required this.color,
    required this.badge,
    required this.date,
    required this.onOpen,
    required this.onRead,
  });

  final Map<String, dynamic> item;
  final IconData icon;
  final Color color;
  final String badge;
  final String date;
  final VoidCallback onOpen;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final unread = (item['estado'] ?? '') == 'no_leida';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: const Color(0x1A0F172A),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (item['titulo'] ?? 'Notificación').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (item['mensaje'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Badge(text: badge, color: color),
                        Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        if (unread)
                          TextButton(
                            onPressed: onRead,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Marcar como leída'),
                          )
                        else
                          const Text('Leída', style: TextStyle(fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
