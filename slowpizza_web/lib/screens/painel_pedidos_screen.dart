import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PainelPedidosScreen extends StatefulWidget {
  const PainelPedidosScreen({super.key});

  @override
  State<PainelPedidosScreen> createState() => _PainelPedidosScreenState();
}

class _PainelPedidosScreenState extends State<PainelPedidosScreen> {
  String filtroStatus = 'todos';

  final List<String> statusOptions = [
    'todos',
    'recebido',
    'em_preparo',
    'pronto',
    'retirado',
    'cancelado',
    'pago',  // <-- ADICIONADO
  ];

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'recebido':
        return Icons.inbox;
      case 'em_preparo':
        return Icons.local_pizza;
      case 'pronto':
        return Icons.check_circle;
      case 'retirado':
        return Icons.shopping_bag;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'recebido':
        return Colors.blueAccent;
      case 'em_preparo':
        return Colors.orangeAccent;
      case 'pronto':
        return Colors.green;
      case 'retirado':
        return Colors.indigo;
      case 'cancelado':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // 🔹 Stream principal de pedidos (corrigido)
  Stream<QuerySnapshot> getPedidosStream() {
    final collection = FirebaseFirestore.instance.collection('pedidos');

    if (filtroStatus == 'todos') {
      return collection.orderBy('criado_em', descending: true).snapshots();
    } else {
      // 🔧 Remove o orderBy para evitar erro de índice e ordena depois manualmente
      return collection.where('status', isEqualTo: filtroStatus).snapshots();
    }
  }

  Future<void> atualizarStatus(String pedidoId, String novoStatus) async {
    await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(pedidoId)
        .update({'status': novoStatus.toLowerCase()});

    setState(() {});
  }

  Future<Map<String, int>> contarPedidosPorStatus() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('pedidos').get();
    final counts = {
      'recebido': 0,
      'em_preparo': 0,
      'pronto': 0,
      'retirado': 0,
      'cancelado': 0,
      'pago': 0, // <-- ADICIONADO
    };

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status =
          (data['status'] ?? '').toString().toLowerCase().trim();
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pedidos"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          FutureBuilder<Map<String, int>>(
            future: contarPedidosPorStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              if (!snapshot.hasData) return const SizedBox.shrink();

              final counts = snapshot.data!;
              return SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                  children: [
                    for (var status in counts.keys)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Card(
                          elevation: 3,
                          color: getStatusColor(status).withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  getStatusIcon(status),
                                  color: getStatusColor(status),
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: getStatusColor(status),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "${counts[status]} pedidos",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: filtroStatus,
              items: statusOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  filtroStatus = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: "Filtrar por status",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getPedidosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("⚠️ Erro ao carregar pedidos"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 🔧 Ordenação manual quando o filtro é aplicado
                List<QueryDocumentSnapshot> pedidos =
                    snapshot.data!.docs.toList();
                if (filtroStatus != 'todos') {
                  pedidos.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTs = aData['criado_em'] as Timestamp?;
                    final bTs = bData['criado_em'] as Timestamp?;
                    if (aTs == null || bTs == null) return 0;
                    return bTs.compareTo(aTs); // mais recentes primeiro
                  });
                }

                if (pedidos.isEmpty) {
                  return const Center(
                      child: Text("Nenhum pedido encontrado"));
                }

                return ListView.builder(
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidos[index];
                    final data = pedido.data() as Map<String, dynamic>;

                    final itens = (data['itens'] ?? []) as List<dynamic>;
                    final total = (data['total'] ?? 0).toDouble();
                    final formaPagamento =
                        data['formaPagamento'] ?? 'não informado';
                    final tipoPedido =
                        data['tipo_pedido'] ?? 'não informado';
                    final status =
                        (data['status'] ?? 'indefinido').toString().toLowerCase();
                    final dataPedido =
                        (data['criado_em'] as Timestamp?)?.toDate();

                    final corStatus = getStatusColor(status);
                    final iconeStatus = getStatusIcon(status);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          iconeStatus,
                          color: corStatus,
                          size: 30,
                        ),
                        title: Text(
                          "Pedido #${pedido.id}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tipo: ${tipoPedido.toUpperCase()}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              "Total: R\$ ${total.toStringAsFixed(2)} • ${formaPagamento.toUpperCase()}",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var item in itens)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    item['nome'] ?? 'Pizza',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    "Qtd: ${item['quantidade']} • Unit: R\$ ${(item['precoUnitario'] ?? 0).toStringAsFixed(2)} • Subtotal: R\$ ${(item['subtotal'] ?? 0).toStringAsFixed(2)}",
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Icon(iconeStatus, color: corStatus, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Status atual: ${status.toUpperCase()}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: corStatus),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButtonFormField<String>(
                                  value: status,
                                  items: statusOptions
                                      .where((s) => s != 'todos')
                                      .map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status.toUpperCase()),
                                    );
                                  }).toList(),
                                  onChanged: (novoStatus) {
                                    if (novoStatus != null) {
                                      atualizarStatus(pedido.id, novoStatus);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: "Alterar status",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (dataPedido != null)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Data: ${dataPedido.day}/${dataPedido.month}/${dataPedido.year} "
                                    "${dataPedido.hour}:${dataPedido.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
