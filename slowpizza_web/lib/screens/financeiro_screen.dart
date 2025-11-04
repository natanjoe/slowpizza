import 'package:flutter/material.dart';

class FinanceiroScreen extends StatelessWidget {
  const FinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Financeiro")),
      body: const Center(child: Text("Resumo financeiro aqui")),
    );
  }
}
