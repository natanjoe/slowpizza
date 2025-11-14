import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime? dataInicio;
  DateTime? dataFim;

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

  // Selecionar intervalo de datas
  Future<void> _selecionarDatas() async {
    final intervalo = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: dataInicio != null && dataFim != null
          ? DateTimeRange(start: dataInicio!, end: dataFim!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (intervalo != null) {
      setState(() {
        dataInicio = intervalo.start;
        dataFim = intervalo.end.add(const Duration(hours: 23, minutes: 59));
      });
    }
  }

  // Popup de erro padronizado (simples)
  Future<void> _mostrarErroPopupSimples(String mensagem) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('Atenção', style: AppTextStyles.subheading),
          ],
        ),
        content: Text(mensagem, style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Exibir popup de novo pedido (mensagens de erro dentro do próprio dialog)
  Future<void> _mostrarDialogoNovoPedido() async {
    String? clienteSelecionado;
    String? mesaSelecionada;
    String? formaPagamentoSelecionada;
    String? tipoPedidoSelecionado = 'balcao';
    List<Map<String, dynamic>> itens = [];
    double total = 0.0;

    final clientesSnapshot = await _db.collection('clientes').get();
    final pizzasSnapshot =
        await _db.collection('pizzas').where('disponivel', isEqualTo: true).get();
    final mesasSnapshot = await _db.collection('mesas').get();

    // função para recalcular total
    void _recalcularTotal() {
      total = itens.fold(0.0, (soma, item) => soma + (item['subtotal'] as double));
    }

    // Adicionar item ao pedido
    Future<void> adicionarItem() async {
      String? pizzaSelecionada1;
      String? pizzaSelecionada2;
      int quantidade = 1;

      await showDialog(
        context: context,
        builder: (_) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth > 800 ? screenWidth * 0.5 : screenWidth * 0.9;
          final dialogHeight =
              screenWidth > 800 ? MediaQuery.of(context).size.height * 0.6 : null;

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight ?? double.infinity),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Adicionar Pizza", style: AppTextStyles.subheading),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(labelText: "1ª metade"),
                                  items: pizzasSnapshot.docs.map((doc) {
                                    final data = doc.data();
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(data['nome'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      pizzaSelecionada1 = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(labelText: "2ª metade (opcional)"),
                                  items: pizzasSnapshot.docs.map((doc) {
                                    final data = doc.data();
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(data['nome'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      pizzaSelecionada2 = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: '1',
                                  decoration: const InputDecoration(labelText: "Quantidade"),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    quantidade = int.tryParse(val) ?? 1;
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (pizzaSelecionada1 != null) {
                              final pizza1 = pizzasSnapshot.docs.firstWhere((p) => p.id == pizzaSelecionada1!);
                              final data1 = pizza1.data();
                              double preco1 = (data1['preco'] ?? 0).toDouble();
                              String nome1 = data1['nome'] ?? '';

                              double precoFinal = preco1;
                              String nomePizza = nome1;

                              // Se tiver segunda metade, calcular média
                              if (pizzaSelecionada2 != null) {
                                final pizza2 = pizzasSnapshot.docs.firstWhere((p) => p.id == pizzaSelecionada2!);
                                final data2 = pizza2.data();
                                double preco2 = (data2['preco'] ?? 0).toDouble();
                                String nome2 = data2['nome'] ?? '';

                                precoFinal = (preco1 + preco2) / 2;
                                nomePizza = "1/2 $nome1 + 1/2 $nome2";
                              }

                              final subtotal = precoFinal * quantidade;

                              itens.add({
                                'pizzaId1': pizzaSelecionada1,
                                if (pizzaSelecionada2 != null) 'pizzaId2': pizzaSelecionada2,
                                'nome': nomePizza,
                                'quantidade': quantidade,
                                'precoUnitario': precoFinal,
                                'subtotal': subtotal,
                              });

                              _recalcularTotal();
                              setState(() {}); // atualiza a tela principal caso necessário
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Adicionar"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Popup principal agora com mensagem de erro exibida DENTRO do dialog
    await showDialog(
      context: context,
      builder: (_) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 800 ? screenWidth * 0.6 : screenWidth * 0.9;
        final dialogHeight = screenWidth > 800 ? MediaQuery.of(context).size.height * 0.8 : null;

        String? erroMensagem; // variável local do popup para mostrar mensagens de erro

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight ?? double.infinity),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(builder: (context, setStateDialog) {
                _recalcularTotal();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Novo Pedido", style: AppTextStyles.subheading),
                    const SizedBox(height: 16),

                    // Cliente
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
                          erroMensagem = null; // limpar erro ao selecionar
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Mesa
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Mesa (opcional)"),
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

                    const SizedBox(height: 12),

                    // Forma de pagamento
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Forma de Pagamento"),
                      items: formasPagamento.map((fp) {
                        return DropdownMenuItem(
                          value: fp,
                          child: Text(fp),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          formaPagamentoSelecionada = val;
                          erroMensagem = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Tipo do pedido
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Tipo do Pedido"),
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

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Adicionar Pizza"),
                      onPressed: () async {
                        await adicionarItem();
                        setStateDialog(() {
                          erroMensagem = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                    ),

                    const SizedBox(height: 12),

                    // Lista de itens
                    if (itens.isNotEmpty)
                      ...itens.map((item) => ListTile(
                            title: Text(item['nome']),
                            subtitle: Text(
                                "Qtd: ${item['quantidade']} | Unit: R\$ ${(item['precoUnitario']).toStringAsFixed(2)}"),
                            trailing: Text("R\$ ${(item['subtotal']).toStringAsFixed(2)}"),
                          )),

                    const Divider(),
                    Text("Total: R\$ ${total.toStringAsFixed(2)}", style: AppTextStyles.highlight),

                    const SizedBox(height: 16),

                    // Mensagem de erro DENTRO do popup (padronizada)
                    if (erroMensagem != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8, bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                erroMensagem!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            // VALIDAÇÕES: setStateDialog atualiza a mensagem dentro do mesmo dialog
                            if (clienteSelecionado == null) {
                              setStateDialog(() {
                                erroMensagem = "Selecione um cliente antes de salvar o pedido.";
                              });
                              return;
                            }

                            if (formaPagamentoSelecionada == null) {
                              setStateDialog(() {
                                erroMensagem = "Selecione a forma de pagamento.";
                              });
                              return;
                            }

                            if (itens.isEmpty) {
                              setStateDialog(() {
                                erroMensagem = "Adicione pelo menos 1 pizza ao pedido.";
                              });
                              return;
                            }

                            final clienteDoc = clientesSnapshot.docs.firstWhere((c) => c.id == clienteSelecionado);
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
                              if (mesaSelecionada != null) 'mesaId': mesaSelecionada,
                            });

                            Navigator.pop(context);
                            setState(() {}); // atualiza a tela principal
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text("Salvar Pedido"),
                        ),
                      ],
                    )
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // Stream dos pedidos
  Stream<QuerySnapshot> getPedidosStream() {
    Query query = _db.collection('pedidos').orderBy('criado_em', descending: true);

    if (dataInicio != null && dataFim != null) {
      query = query
          .where('criado_em', isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio!))
          .where('criado_em', isLessThanOrEqualTo: Timestamp.fromDate(dataFim!));
    }

    return query.snapshots();
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.collection('pedidos').doc(id).update({'status': novoStatus});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Pedidos", style: AppTextStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _selecionarDatas,
            icon: const Icon(Icons.date_range),
            tooltip: "Filtrar por data",
          ),
          if (dataInicio != null)
            IconButton(
              onPressed: () {
                setState(() {
                  dataInicio = null;
                  dataFim = null;
                });
              },
              icon: const Icon(Icons.clear),
              tooltip: "Limpar filtro",
            ),
        ],
      ),
      body: Column(
        children: [
          if (dataInicio != null)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.2),
              padding: const EdgeInsets.all(8),
              child: Text(
                "Período: ${formato.format(dataInicio!)} até ${formato.format(dataFim!)}",
                textAlign: TextAlign.center,
                style: AppTextStyles.tileSubtitle,
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                  return const Center(child: Text("Nenhum pedido encontrado."));
                }

                return ListView.builder(
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidos[index];
                    final data = pedido.data() as Map<String, dynamic>;
                    final dataPedido = (data['criado_em'] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ExpansionTile(
                        leading: const Icon(Icons.receipt_long, color: AppColors.primary),
                        title: Text(
                          "Cliente: ${data['clienteNome']}",
                          style: AppTextStyles.tileTitle,
                        ),
                        subtitle: Text(
                          "Total: R\$ ${(data['total'] ?? 0).toStringAsFixed(2)} • ${data['formaPagamento']}\n"
                          "Data: ${formato.format(dataPedido)}",
                          style: AppTextStyles.tileSubtitle,
                        ),
                        children: [
                          for (var item in (data['itens'] ?? []))
                            ListTile(
                              dense: true,
                              title: Text(item['nome'], style: AppTextStyles.tileSubtitle),
                              subtitle: Text(
                                "Qtd: ${item['quantidade']} | Unit: R\$ ${(item['precoUnitario']).toStringAsFixed(2)}",
                                style: AppTextStyles.tileInfo,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: DropdownButtonFormField<String>(
                              value: data['status'],
                              items: const [
                                DropdownMenuItem(value: 'recebido', child: Text("RECEBIDO")),
                                DropdownMenuItem(value: 'em_preparo', child: Text("EM PREPARO")),
                                DropdownMenuItem(value: 'pronto', child: Text("PRONTO")),
                                DropdownMenuItem(value: 'retirado', child: Text("RETIRADO")),
                                DropdownMenuItem(value: 'cancelado', child: Text("CANCELADO")),
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

                          // BOTÃO DE EXCLUIR
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: const Text("Excluir Pedido"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Excluir Pedido"),
                                    content: const Text("Tem certeza que deseja excluir este pedido?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Cancelar"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("Excluir"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmar == true) {
                                  await _db.collection('pedidos').doc(pedido.id).delete();
                                  // opcional: mostrar confirmação
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pedido excluído com sucesso.')),
                                    );
                                  }
                                }
                              },
                            ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNovoPedido,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
