// flutter-app/lib/screens/seguimiento_screen.dart
// Pantalla que muestra:
//   - Mapa con rastreo en tiempo real del técnico
//   - Chat con el taller
//   - ETA actualizado en vivo
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SeguimientoScreen extends StatefulWidget {
  final String incidenteId;
  final double latCliente;
  final double lngCliente;
  const SeguimientoScreen({
    super.key,
    required this.incidenteId,
    required this.latCliente,
    required this.lngCliente,
  });
  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WebSocketChannel _chatWS;
  late WebSocketChannel _trackWS;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _mensajes = [];

  LatLng? _posicionTecnico;
  int _etaMinutos = 0;
  String _estado = 'en_proceso';

  static const _wsBase = 'ws://localhost:8000/api/ws';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _conectarChat();
    _conectarTracking();
  }

  void _conectarChat() {
    _chatWS = WebSocketChannel.connect(
      Uri.parse('$_wsBase/chat/${widget.incidenteId}'),
    );
    _chatWS.stream.listen((data) {
      final msg = jsonDecode(data);
      setState(() => _mensajes.add(msg));
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    });
  }

  void _conectarTracking() {
    _trackWS = WebSocketChannel.connect(
      Uri.parse('$_wsBase/tracking/${widget.incidenteId}'),
    );
    _trackWS.stream.listen((data) {
      final payload = jsonDecode(data);
      if (payload['tipo'] == 'ubicacion_tecnico') {
        setState(() {
          _posicionTecnico = LatLng(payload['lat'], payload['lng']);
          _etaMinutos = payload['eta_minutos'] ?? 0;
        });
      }
      if (payload['tipo'] == 'estado') {
        setState(() => _estado = payload['estado']);
      }
    });
  }

  void _enviarMensaje() {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty) return;
    _chatWS.sink.add(jsonEncode({
      'autor': 'conductor',
      'texto': texto,
      'tipo': 'texto',
    }));
    _msgCtrl.clear();
  }

  @override
  void dispose() {
    _chatWS.sink.close();
    _trackWS.sink.close();
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE24B4A),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Asistencia en camino', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(_etaMinutos > 0 ? 'ETA: $_etaMinutos min' : 'Localizando técnico...',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Mapa'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildMapa(),
          _buildChat(),
        ],
      ),
    );
  }

  Widget _buildMapa() {
    final latCliente = widget.latCliente;
    final lngCliente = widget.lngCliente;

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: _posicionTecnico ?? LatLng(latCliente, lngCliente),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(markers: [
            // Marcador cliente
            Marker(
              point: LatLng(latCliente, lngCliente),
              child: const Icon(Icons.person_pin_circle, color: Color(0xFF185FA5), size: 36),
            ),
            // Marcador técnico (si disponible)
            if (_posicionTecnico != null)
              Marker(
                point: _posicionTecnico!,
                child: const Icon(Icons.build_circle, color: Color(0xFFE24B4A), size: 36),
              ),
          ]),
          if (_posicionTecnico != null)
            PolylineLayer(polylines: [
              Polyline(
                points: [_posicionTecnico!, LatLng(latCliente, lngCliente)],
                color: const Color(0xFFE24B4A),
                strokeWidth: 2,
                isDotted: true,
              ),
            ]),
        ],
      ),
      // Card ETA
      Positioned(
        bottom: 16, left: 16, right: 16,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build, color: Color(0xFFE24B4A)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _etaMinutos > 0 ? 'Técnico a $_etaMinutos minutos' : 'Localizando...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    _estado == 'en_proceso' ? 'En camino a tu ubicación' : _estado,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _posicionTecnico != null ? 'GPS activo' : 'Buscando',
                  style: const TextStyle(color: Color(0xFF3B6D11), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildChat() {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: _mensajes.length,
          itemBuilder: (ctx, i) {
            final msg = _mensajes[i];
            final esMio = msg['autor'] == 'conductor';
            return Align(
              alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  color: esMio ? const Color(0xFFE24B4A) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(esMio ? 14 : 2),
                    bottomRight: Radius.circular(esMio ? 2 : 14),
                  ),
                  border: esMio ? null : Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!esMio)
                    Text('Taller', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Text(msg['texto'] ?? '',
                      style: TextStyle(color: esMio ? Colors.white : Colors.black87, fontSize: 14)),
                  Text(
                    msg['timestamp'] != null
                        ? _formatHora(msg['timestamp'])
                        : '',
                    style: TextStyle(fontSize: 10, color: esMio ? Colors.white60 : Colors.grey.shade400),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                filled: true,
                fillColor: const Color(0xFFF5F4F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviarMensaje,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE24B4A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
    ]);
  }

  String _formatHora(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}
