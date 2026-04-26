import 'package:flutter/material.dart';
import 'package:auxilio_scz/features/emergencias/services/emergencias_api.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final api = EmergenciesApi();

  Future<void> pagar() async {
    try {
      final res = await api.processPayment(
        incidenteId: "ID_AQUI",
        metodo: "tarjeta",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['mensaje'] ?? 'Pago exitoso')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pago")),
      body: Center(
        child: ElevatedButton(
          onPressed: pagar,
          child: const Text("Pagar"),
        ),
      ),
    );
  }
}
