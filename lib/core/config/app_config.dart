import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Allow overriding from CLI:
      // flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
      const fromEnv = String.fromEnvironment('API_BASE_URL');
      if (fromEnv.isNotEmpty) return fromEnv;

      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:8000/api';
      }
      return 'http://localhost:8000/api';
    }

    // Android emulator must use 10.0.2.2 to access host machine.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    // iOS simulator can use localhost.
    return 'http://localhost:8000/api';
  }
}
