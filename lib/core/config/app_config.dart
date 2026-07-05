import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Allow overriding from CLI:
      // flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
      const fromEnv = String.fromEnvironment('API_BASE_URL');
      if (fromEnv.isNotEmpty) return fromEnv;

      final host = Uri.base.host;
      // Keep local development stable across localhost/IPv4/IPv6 variants.
      const localHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1', '[::1]'};
      if (host.isNotEmpty && !localHosts.contains(host)) {
        return 'http://$host:8000/api';
      }
      return 'http://192.168.0.7:8000/api';
    }

    // Permite sobreescribir la URL en compilación/dev:
    //   flutter run --dart-define=API_BASE_URL=http://192.168.0.7:8001/api
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // APK de producción (descargable): apunta al backend desplegado en Railway
    // para que funcione en cualquier red, no solo en la WiFi local.
    return 'https://auxiliscz-backend-production.up.railway.app/api';
  }
}
