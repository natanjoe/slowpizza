// lib/screens/vendas_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/venda_service.dart';

class VendasScreen extends StatefulWidget {
  const VendasScreen({super.key});

  @override
  State<VendasScreen> createState() => _VendasScreenState();
}

class _VendasScreenState extends State<VendasScreen> {
  final VendaService vendaService = VendaService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // pequeno formulário manual (somente para testar function)
  final TextEditingController pedidoIdCtrl = TextEditingController();
  final TextEditingController valorCtrl = TextEditingController(text: "0.00");
  String formaPagamento = "Pix";

  bool loading = false;

  Future<void> _criarVendaTeste() async {
    final pedidoId = pedidoIdCtrl.text.trim();
    final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (pedidoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe pedidoId")));
      return;
    }
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Valor inválido")));
      return;
    }

    setState(() => loading = true);
    try {
      // aqui montamos itens fictícios: por compatibilidade com function, precisamos pelo menos 1 item com id_pizza e quantidade
      final itens = [
        {'id_pizza': 'TESTE_PIZZA', 'quantidade': 1}
      ];

      final id = await vendaService.registrarVenda(
        pedidoId: pedidoId,
        valorBruto: valor,
        valorLiquido: valor,
        formaPagamento: formaPagamento,
        tipoPedido: 'balcao',
        recebidoPor: 'manual_test',
        itens: itens,
      );

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Venda criada: $id")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    pedidoIdCtrl.dispose();
    valorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendas / Testes"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: pedidoIdCtrl,
              decoration: const InputDecoration(labelText: "pedidoId (use um id existente para testar)"),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: valorCtrl, decoration: const InputDecoration(labelText: "Valor"), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: formaPagamento,
                  items: const [
                    DropdownMenuItem(value: "Dinheiro", child: Text("Dinheiro")),
                    DropdownMenuItem(value: "Pix", child: Text("Pix")),
                    DropdownMenuItem(value: "Cartão", child: Text("Cartão")),
                  ],
                  onChanged: (v) => setState(() => formaPagamento = v ?? "Pix"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : _criarVendaTeste,
              child: loading ? const CircularProgressIndicator() : const Text("Registrar Venda (test)"),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Vendas recentes"),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('vendas').orderBy('criado_em', descending: true).limit(50).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final d = docs[index];
                      final data = d.data() as Map<String, dynamic>;
                      final valor = (data['valor_liquido'] ?? data['valor_liquido'] ?? 0).toDouble();
                      final forma = (data['forma_pagamento'] ?? '').toString();
                      return ListTile(
                        title: Text("Venda ${d.id.substring(0, 8)} - R\$ ${valor.toStringAsFixed(2)}"),
                        subtitle: Text(forma),
                        trailing: Text((data['tipo_pedido'] ?? '').toString()),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
