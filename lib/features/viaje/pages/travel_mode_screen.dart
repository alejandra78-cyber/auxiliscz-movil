import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/navigation_helper.dart';
import '../services/travel_mode_controller.dart';

/// Pantalla completa del Modo Viaje: mapa centrado en la ubicación actual,
/// búsqueda de destino y botón para iniciar la navegación externa.
class TravelModeScreen extends StatefulWidget {
  const TravelModeScreen({super.key});

  @override
  State<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends State<TravelModeScreen> {
  final _controller = TravelModeController.instance;
  final _mapController = MapController();
  final _busquedaCtrl = TextEditingController();
  bool _lanzando = false;

  // Centro por defecto: Santa Cruz de la Sierra.
  static const _centroDefecto = LatLng(-17.7833, -63.1821);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _centrarEnUbicacion();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _busquedaCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _centrarEnUbicacion() async {
    final punto = await _controller.obtenerUbicacionActual();
    if (!mounted || punto == null) return;
    _mapController.move(punto, 15);
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    await _controller.buscarDestino(_busquedaCtrl.text);
    if (!mounted) return;
    if (_controller.resultadosBusqueda.isEmpty && !_controller.buscando) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron resultados')),
      );
    }
  }

  void _seleccionarDestino(DestinoViaje destino) {
    _controller.seleccionarDestino(destino);
    _mapController.move(destino.punto, 15);
  }

  Future<void> _iniciarNavegacion() async {
    final destino = _controller.destino;
    if (destino == null || _lanzando) return;
    setState(() => _lanzando = true);
    try {
      final origen = _controller.ubicacionActual;
      final abierto = await NavigationHelper.iniciarNavegacion(
        destinoLat: destino.punto.latitude,
        destinoLng: destino.punto.longitude,
        origenLat: origen?.latitude,
        origenLng: origen?.longitude,
      );
      if (!mounted) return;
      if (!abierto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google Maps no está instalado. Te llevamos a la Play Store.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _lanzando = false);
    }
  }

  Future<void> _desactivarModoViaje() async {
    await _controller.desactivar();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ubicacion = _controller.ubicacionActual;
    final destino = _controller.destino;
    final resultados = _controller.resultadosBusqueda;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Viaje'),
        actions: [
          IconButton(
            tooltip: 'Desactivar Modo Viaje',
            onPressed: _desactivarModoViaje,
            icon: const Icon(Icons.power_settings_new),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: ubicacion ?? _centroDefecto,
              initialZoom: 14,
              onTap: (_, punto) => _seleccionarDestino(
                DestinoViaje(
                  nombre:
                      'Punto en el mapa (${punto.latitude.toStringAsFixed(5)}, '
                      '${punto.longitude.toStringAsFixed(5)})',
                  punto: punto,
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.auxilioscz.app',
              ),
              MarkerLayer(
                markers: [
                  if (ubicacion != null)
                    Marker(
                      width: 44,
                      height: 44,
                      point: ubicacion,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 34,
                      ),
                    ),
                  if (destino != null)
                    Marker(
                      width: 44,
                      height: 44,
                      point: destino.punto,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Barra de búsqueda de destino
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _busquedaCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: 'Buscar destino…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.buscando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              onPressed: _buscar,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                if (resultados.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: resultados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = resultados[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place, size: 20),
                          title: Text(
                            r.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _seleccionarDestino(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Tarjeta del destino seleccionado
          if (destino != null)
            Positioned(
              bottom: 96,
              left: 12,
              right: 12,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.flag, color: Colors.red),
                  title: Text(
                    destino.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Quitar destino',
                    onPressed: _controller.limpiarDestino,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_centrar',
            tooltip: 'Centrar en mi ubicación',
            onPressed: _centrarEnUbicacion,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_navegar',
            onPressed:
                (destino != null && !_lanzando) ? _iniciarNavegacion : null,
            backgroundColor: destino != null ? null : Colors.grey,
            icon: _lanzando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.navigation),
            label: Text(_lanzando ? 'Abriendo…' : 'Iniciar Navegación'),
          ),
        ],
      ),
    );
  }
}
