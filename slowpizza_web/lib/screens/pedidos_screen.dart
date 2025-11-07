import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<String> formasPagamento = [
    'Dinheiro',
    'Pix',
    'Cartão de Crédito',
    'Cartão de Débito',
    'Vale Refeição',
  ];

  final List<String> tiposPedido = [
    'balcao',
    'telefone',
    'app',
    'site',
  ];

  // 🔹 Criação de novo pedido
  Future<void> _mostrarDialogoNovoPedido() async {
    String? clienteSelecionado;
    String? mesaSelecionada;
    String? formaPagamentoSelecionada;
    String? tipoPedidoSelecionado = 'balcao';
    List<Map<String, dynamic>> itens = [];
    double total = 0.0;

    final clientesSnapshot = await _db.collection('clientes').get();
    final pizzasSnapshot = await _db
        .collection('pizzas')
        .where('disponivel', isEqualTo: true)
        .get();
    final mesasSnapshot = await _db.collection('mesas').get();

    // 🔹 Adicionar item (pizza ou meia pizza)
  Future<void> adicionarItem(StateSetter setStateDialog) async {
  List<String> pizzasSelecionadas = [];
  int quantidade = 1;

  await showDialog(
    context: context,
    builder: (_) {
      final isDesktop = MediaQuery.of(context).size.width > 600;
      final dialogWidth = isDesktop ? 650.0 : double.infinity;
      final dialogHeight = isDesktop ? 600.0 : 500.0;

      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 100 : 20,
          vertical: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setStateInner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Selecionar Pizza(s)",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Marque 1 sabor para pizza inteira ou 2 sabores para meia a meia:",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),

                  // 🔹 Lista rolável de pizzas disponíveis
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: pizzasSnapshot.docs.length,
                        itemBuilder: (context, index) {
                          final doc = pizzasSnapshot.docs[index];
                          final data = doc.data();
                          final nome = data['nome'] ?? 'Sem nome';
                          final preco = (data['preco'] ?? 0).toDouble();

                          return CheckboxListTile(
                            title: Text("$nome  (R\$ ${preco.toStringAsFixed(2)})"),
                            value: pizzasSelecionadas.contains(doc.id),
                            onChanged: (bool? selected) {
                              setStateInner(() {
                                if (selected == true) {
                                  if (pizzasSelecionadas.length < 2) {
                                    pizzasSelecionadas.add(doc.id);
                                  }
                                } else {
                                  pizzasSelecionadas.remove(doc.id);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: '1',
                    decoration: const InputDecoration(
                      labelText: "Quantidade de pizzas",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) =>
                        quantidade = int.tryParse(val) ?? 1,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          if (pizzasSelecionadas.isEmpty ||
                              pizzasSelecionadas.length > 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Selecione 1 pizza (inteira) ou 2 sabores (meia a meia).",
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          // 🔹 Pega dados das pizzas selecionadas
                          final pizzaDocs = pizzasSnapshot.docs
                              .where((p) => pizzasSelecionadas.contains(p.id))
                              .toList();

                          double precoFinal = 0.0;
                          String nomeFinal = "";

                          if (pizzaDocs.length == 1) {
                            final data = pizzaDocs.first.data();
                            precoFinal = (data['preco'] ?? 0).toDouble();
                            nomeFinal = data['nome'] ?? 'Pizza';
                          } else if (pizzaDocs.length == 2) {
                            final data1 = pizzaDocs[0].data();
                            final data2 = pizzaDocs[1].data();
                            final preco1 = (data1['preco'] ?? 0).toDouble();
                            final preco2 = (data2['preco'] ?? 0).toDouble();
                            precoFinal = (preco1 + preco2) / 2;
                            nomeFinal =
                                "½ ${data1['nome']} + ½ ${data2['nome']}";
                          }

                          final subtotal = precoFinal * quantidade;

                          itens.add({
                            'nome': nomeFinal,
                            'quantidade': quantidade,
                            'precoUnitario': precoFinal,
                            'subtotal': subtotal,
                          });

                          total = itens.fold(
                              0.0,
                              (sum, item) =>
                                  sum + (item['subtotal'] ?? 0.0));

                          setStateDialog(() {});
                          Navigator.pop(context);
                        },
                        child: const Text("Adicionar ao Pedido"),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}


    // 🔹 Popup principal de criação de pedido
    await showDialog(
      context: context,
      builder: (_) {
        final isDesktop = MediaQuery.of(context).size.width > 600;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 150 : 20,
            vertical: 20,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(builder: (context, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Novo Pedido",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Cliente"),
                      items: clientesSnapshot.docs.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['nome'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          clienteSelecionado = val;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: "Mesa (opcional)"),
                      items: mesasSnapshot.docs.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text("Mesa ${data['numero']}"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          mesaSelecionada = val;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: "Forma de Pagamento"),
                      items: formasPagamento.map((fp) {
                        return DropdownMenuItem(
                          value: fp,
                          child: Text(fp),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          formaPagamentoSelecionada = val;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: "Tipo do Pedido"),
                      value: tipoPedidoSelecionado,
                      items: tiposPedido.map((tp) {
                        return DropdownMenuItem(
                          value: tp,
                          child: Text(tp.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          tipoPedidoSelecionado = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Adicionar Pizza"),
                      onPressed: () => adicionarItem(setStateDialog),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent),
                    ),
                    const SizedBox(height: 10),

                    // 🔹 Lista dinâmica de pizzas adicionadas
                    if (itens.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text("Itens adicionados:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          ...itens.map((item) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(item['nome']),
                              subtitle: Text(
                                  "Qtd: ${item['quantidade']}  •  Unit: R\$ ${item['precoUnitario'].toStringAsFixed(2)}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "R\$ ${item['subtotal'].toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      itens.remove(item);
                                      total = itens.fold(
                                          0.0,
                                          (sum, item) =>
                                              sum + (item['subtotal'] ?? 0.0));
                                      setStateDialog(() {});
                                    },
                                  )
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "Total: R\$ ${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (clienteSelecionado != null &&
                                formaPagamentoSelecionada != null &&
                                itens.isNotEmpty) {
                              final clienteDoc = clientesSnapshot.docs
                                  .firstWhere(
                                      (c) => c.id == clienteSelecionado);
                              final clienteData = clienteDoc.data();

                              await _db.collection('pedidos').add({
                                'clienteNome': clienteData['nome'],
                                'clienteTelefone': clienteData['telefone'],
                                'itens': itens,
                                'formaPagamento': formaPagamentoSelecionada,
                                'status': 'recebido',
                                'tipo_pedido': tipoPedidoSelecionado,
                                'total': total,
                                'criado_em': Timestamp.now(),
                                if (mesaSelecionada != null)
                                  'mesaId': mesaSelecionada,
                              });

                              Navigator.pop(context);
                              setState(() {});
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: const Text("Salvar Pedido"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // 🔹 Stream de pedidos
  Stream<QuerySnapshot> getPedidosStream() {
    return _db
        .collection('pedidos')
        .orderBy('criado_em', descending: true)
        .snapshots();
  }

  // 🔹 Atualizar status
  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.collection('pedidos').doc(id).update({'status': novoStatus});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pedidos do Balcão"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getPedidosStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar pedidos."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pedidos = snapshot.data!.docs;
          if (pedidos.isEmpty) {
            return const Center(child: Text("Nenhum pedido cadastrado."));
          }

          return ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              final data = pedido.data() as Map<String, dynamic>;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long,
                      color: AppColors.primary),
                  title: Text(
                    "Cliente: ${data['clienteNome']}",
                    style: AppTextStyles.subheading,
                  ),
                  subtitle: Text(
                    "Total: R\$ ${(data['total'] ?? 0).toStringAsFixed(2)} • ${data['formaPagamento']}",
                    style: AppTextStyles.body,
                  ),
                  children: [
                    for (var item in (data['itens'] ?? []))
                      ListTile(
                        dense: true,
                        title: Text(item['nome']),
                        subtitle: Text(
                            "Qtd: ${item['quantidade']} | Unit: R\$ ${(item['precoUnitario']).toStringAsFixed(2)}"),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButtonFormField<String>(
                        value: data['status'],
                        items: const [
                          DropdownMenuItem(
                              value: 'recebido', child: Text("RECEBIDO")),
                          DropdownMenuItem(
                              value: 'em_preparo', child: Text("EM PREPARO")),
                          DropdownMenuItem(
                              value: 'pronto', child: Text("PRONTO")),
                          DropdownMenuItem(
                              value: 'retirado', child: Text("RETIRADO")),
                          DropdownMenuItem(
                              value: 'cancelado', child: Text("CANCELADO")),
                        ],
                        onChanged: (val) {
                          if (val != null) atualizarStatus(pedido.id, val);
                        },
                        decoration: const InputDecoration(
                          labelText: "Alterar status",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNovoPedido,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
