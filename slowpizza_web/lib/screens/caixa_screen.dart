// lib/screens/caixa_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/caixa_service.dart'; // ← SÓ ESSE IMPORT!
import '../../models/caixa.dart'; // ← só o model

class CaixaScreen extends StatefulWidget {
  const CaixaScreen({super.key});

  @override
  State<CaixaScreen> createState() => _CaixaScreenState();
}

class _CaixaScreenState extends State<CaixaScreen> {
  final CaixaService _service = CaixaService();

  @override
  Widget build(BuildContext context) {
    final formatoData = DateFormat('dd/MM/yyyy');
    final formatoHora = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Caixa do Dia"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Caixa?>(
        stream: _service.streamCaixaHoje(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final caixa = snap.data;

          if (caixa == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Caixa ainda não aberto hoje",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text("Faça a primeira venda para abrir automaticamente"),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // === CABEÇALHO ===
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          "CAIXA ABERTO",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(formatoData.format(caixa.data), style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // === SALDOS ===
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text("Saldo Inicial"),
                          trailing: Text("R\$ ${caixa.saldoInicial.toStringAsFixed(2)}"),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.deepPurple.shade50,
                        child: ListTile(
                          title: const Text("SALDO ATUAL", style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            "R\$ ${caixa.saldoFinal.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // === TOTALIZADORES ===
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.arrow_upward, color: Colors.green),
                          title: const Text("Entradas"),
                          trailing: Text("R\$ ${caixa.totalEntradas.toStringAsFixed(2)}"),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.arrow_downward, color: Colors.red),
                          title: const Text("Saídas"),
                          trailing: Text("R\$ ${caixa.totalSaidas.toStringAsFixed(2)}"),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Divider(),
                const Text("Movimentos do Dia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // === LISTA DE MOVIMENTOS ===
                Expanded(
                  child: caixa.movimentos.isEmpty
                      ? const Center(child: Text("Nenhum movimento ainda"))
                      : ListView.separated(
                          itemCount: caixa.movimentos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = caixa.movimentos[index];
                            final hora = formatoHora.format(m.timestamp);
                            final isEntrada = m.tipo == 'entrada';
                            final cor = isEntrada ? Colors.green : Colors.red;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cor.withOpacity(0.1),
                                child: Text(
                                  isEntrada ? "E" : "S",
                                  style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(m.descricao),
                              subtitle: Text("${m.origem} • $hora"),
                              trailing: Text(
                                "${isEntrada ? '+' : '-'} R\$ ${m.valor.toStringAsFixed(2)}",
                                style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              onTap: m.vendaId != null
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Venda: ${m.vendaId!.id}")),
                                      );
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}