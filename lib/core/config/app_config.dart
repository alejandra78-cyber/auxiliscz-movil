import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    // WEB
    if (kIsWeb) {
      final host = Uri.base.host;

      const localHosts = {
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '::1',
        '[::1]',
      };

      if (host.isNotEmpty && !localHosts.contains(host)) {
        return 'http://$host:8000/api';
      }

      return 'http://127.0.0.1:8000/api';
    }

    // ANDROID (CELULAR FÍSICO)
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Para pruebas por USB usa:
      // adb reverse tcp:8000 tcp:8000
      // Luego `flutter run` funciona apuntando al backend local.
      return 'http://127.0.0.1:8000/api';
    }

    // IOS
    return 'http://localhost:8000/api';
  }

  static String get wsBaseUrl {
    final api = baseUrl;
    final withoutApi = api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
    if (withoutApi.startsWith('https://')) {
      return withoutApi.replaceFirst('https://', 'wss://');
    }
    if (withoutApi.startsWith('http://')) {
      return withoutApi.replaceFirst('http://', 'ws://');
    }
    return withoutApi;
  }
}
