import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    // WEB
    if (kIsWeb) {
      const fromEnv = String.fromEnvironment('API_BASE_URL');

      if (fromEnv.isNotEmpty) {
        return fromEnv;
      }

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
      return 'http://192.168.0.102:8000/api';
    }

    // IOS
    return 'http://localhost:8000/api';
  }
}