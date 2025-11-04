import 'package:flutter/material.dart';

class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pedidos")),
      body: const Center(child: Text("Lista de pedidos aqui")),
    );
  }
}
