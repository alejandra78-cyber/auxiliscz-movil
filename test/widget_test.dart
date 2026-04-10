import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auxilio_scz/main.dart';

void main() {
  testWidgets('App muestra bootstrap al iniciar', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AuxiliSczApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
