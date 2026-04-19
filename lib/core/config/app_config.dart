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
      return 'http://127.0.0.1:8000/api';
    }

    // Android emulator must use 10.0.2.2 to access host machine.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    // iOS simulator can use localhost.
    return 'http://localhost:8000/api';
  }
}