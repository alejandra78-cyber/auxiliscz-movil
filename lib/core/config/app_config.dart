import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool isProduction = true; // 🔥 cambia aquí

  static String get baseUrl {
    if (isProduction) {
      return "https://auxiliscz-backend.onrender.com/api";
    }

    // 👉 desarrollo local
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://localhost:8000/api';
  }
}