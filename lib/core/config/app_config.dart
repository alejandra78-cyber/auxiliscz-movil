import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    // 🔥 ESTO ES LO IMPORTANTE (para APK y web)
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

    // Android emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    // iOS
    return 'http://localhost:8000/api';
  }
}