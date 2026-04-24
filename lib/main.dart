import 'package:flutter/material.dart';

import 'features/auth/pages/login_screen.dart';
import 'routes/app_routes.dart'; // 👈 ESTE FALTABA
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuxiliSczApp());
}

class AuxiliSczApp extends StatelessWidget {
  const AuxiliSczApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuxiliSCZ',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
