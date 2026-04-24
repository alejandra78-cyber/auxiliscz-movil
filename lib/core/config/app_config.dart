import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) {
      final host = Uri.base.host;
      const localHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1', '[::1]'};
      if (host.isNotEmpty && !localHosts.contains(host)) {
        return 'http://$host:8000/api';
      }
      return 'http://127.0.0.1:8000/api';
    }

    // 🔥 ANDROID (CELULAR REAL)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.0.108:8000/api';
    }

    // iOS
    return 'http://localhost:8000/api';
  }
}