import 'package:url_launcher/url_launcher.dart';

/// Helper para lanzar la navegación externa de Google Maps.
///
/// Usa la Directions API por URL (https://www.google.com/maps/dir/?api=1...),
/// que es totalmente gratuita: NO consume la API Key de Google Maps Platform
/// porque solo abre la app externa mediante un intent implícito (ACTION_VIEW).
class NavigationHelper {
  NavigationHelper._();

  static const _playStoreMapsUri =
      'market://details?id=com.google.android.apps.maps';
  static const _playStoreMapsWebUri =
      'https://play.google.com/store/apps/details?id=com.google.android.apps.maps';

  /// Lanza Google Maps con la navegación en modo conducción hacia el destino.
  ///
  /// [origenLat]/[origenLng] son opcionales: si se omiten, Google Maps usa la
  /// ubicación actual del dispositivo como origen (comportamiento recomendado).
  ///
  /// Si Google Maps no está instalado, redirige a la Play Store para
  /// descargarlo. Retorna `true` si se pudo abrir la navegación.
  static Future<bool> iniciarNavegacion({
    required double destinoLat,
    required double destinoLng,
    double? origenLat,
    double? origenLng,
  }) async {
    final origen = (origenLat != null && origenLng != null)
        ? '&origin=$origenLat,$origenLng'
        : '';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '$origen'
      '&destination=$destinoLat,$destinoLng'
      '&travelmode=driving'
      '&dir_action=navigate',
    );

    // 1) Intentar abrir la app nativa de Google Maps (no el navegador).
    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (abierto) return true;
    } catch (_) {
      // ACTIVITY_NOT_FOUND u otro error: seguimos al fallback.
    }

    // 2) Fallback con esquema geo: (cualquier app de mapas instalada).
    try {
      final geoUri = Uri.parse(
        'geo:$destinoLat,$destinoLng?q=$destinoLat,$destinoLng',
      );
      final abierto = await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );
      if (abierto) return true;
    } catch (_) {
      // Sin app de mapas: redirigir a la Play Store.
    }

    // 3) No hay app de mapas: llevar al usuario a la Play Store.
    await _abrirPlayStore();
    return false;
  }

  static Future<void> _abrirPlayStore() async {
    try {
      final abierto = await launchUrl(
        Uri.parse(_playStoreMapsUri),
        mode: LaunchMode.externalApplication,
      );
      if (abierto) return;
    } catch (_) {
      // market:// no disponible (p. ej. sin Play Store): usar la web.
    }
    try {
      await launchUrl(
        Uri.parse(_playStoreMapsWebUri),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Último recurso agotado: no hay forma de abrir mapas ni la tienda.
    }
  }
}
