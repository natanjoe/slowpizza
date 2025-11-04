// lib/screens/pizzas_screen.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PizzasScreen extends StatefulWidget {
  const PizzasScreen({super.key});

  @override
  State<PizzasScreen> createState() => _PizzasScreenState();
}

class _PizzasScreenState extends State<PizzasScreen> {
  Uint8List? _imagemSelecionada;
  String? _imagemNome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pizzas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: () => _showPizzaForm(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pizzas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar pizzas.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pizzas = snapshot.data!.docs;
          if (pizzas.isEmpty) {
            return const Center(child: Text('Nenhuma pizza cadastrada ainda.'));
          }

          return LayoutBuilder(builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            const double gridPadding = 32;
            const double crossAxisSpacing = 16;
            final bool isMobile = totalWidth < 600;
            final int crossAxisCount = isMobile
                ? 2
                : totalWidth < 1000
                    ? 3
                    : 4;

            final double usableWidth =
                max(200, totalWidth - gridPadding - (crossAxisCount - 1) * crossAxisSpacing);
            final double cardWidth = usableWidth / crossAxisCount;

            final double desiredCardHeightMobile = cardWidth * 2.15;
            final double desiredCardHeightDesktop = cardWidth * 0.9;
            final double cardHeight =
                isMobile ? desiredCardHeightMobile : desiredCardHeightDesktop;
            final double childAspectRatio = cardWidth / cardHeight;

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pizzas.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final pizzaDoc = pizzas[index];
                final pizzaData = pizzaDoc.data() as Map<String, dynamic>? ?? {};

                return GestureDetector(
                  onTap: () => _showPizzaForm(context, pizzaDoc: pizzaDoc),
                  child: PizzaCard(
                    nome: (pizzaData['nome'] ?? 'Sem nome').toString(),
                    descricao:
                        (pizzaData['descricao'] ?? 'Sem descrição').toString(),
                    preco: (pizzaData['preco'] is num)
                        ? (pizzaData['preco'] as num).toDouble()
                        : 0.0,
                    imagemUrl: (pizzaData['imagemUrl'] ?? '').toString(),
                    cardHeight: cardHeight,
                  ),
                );
              },
            );
          });
        },
      ),
    );
  }

  Future<void> _showPizzaForm(BuildContext context, {DocumentSnapshot? pizzaDoc}) async {
    final nomeController = TextEditingController(text: pizzaDoc?['nome'] ?? '');
    final descricaoController =
        TextEditingController(text: pizzaDoc?['descricao'] ?? '');
    final precoController =
        TextEditingController(text: pizzaDoc?['preco']?.toString() ?? '');
    final imagemUrlController =
        TextEditingController(text: pizzaDoc?['imagemUrl'] ?? '');

    final mq = MediaQuery.of(context);
    final maxDialogHeight = min(mq.size.height * 0.9, 680.0);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          Future<void> _confirmDelete() async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirmar exclusão'),
                content:
                    const Text('Deseja realmente excluir esta pizza?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Não')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sim')),
                ],
              ),
            );
            if (ok == true && pizzaDoc != null) {
              try {
                await FirebaseFirestore.instance
                    .collection('pizzas')
                    .doc(pizzaDoc.id)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pizza excluída com sucesso')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')));
                }
              }
            }
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              width: mq.size.width * (mq.size.width > 900 ? 0.45 : 0.95),
              height: maxDialogHeight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      pizzaDoc == null ? 'Adicionar Pizza' : 'Editar Pizza',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Preview da imagem (URL digitada)
                            if (imagemUrlController.text.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imagemUrlController.text,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, st) => Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.broken_image, size: 44)),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: imagemUrlController,
                              decoration: const InputDecoration(
                                labelText: 'URL da Imagem (GitHub ou outro)',
                              ),
                              onChanged: (val) => setModalState(() {}),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: nomeController,
                              decoration:
                                  const InputDecoration(labelText: 'Nome da Pizza'),
                            ),
                            const SizedBox(height: 8),

                            TextField(
                              controller: descricaoController,
                              decoration:
                                  const InputDecoration(labelText: 'Descrição'),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 8),

                            TextField(
                              controller: precoController,
                              decoration:
                                  const InputDecoration(labelText: 'Preço'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (pizzaDoc != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: _confirmDelete,
                            icon: const Icon(Icons.delete),
                            label: const Text(''),
                          )
                        else
                          const SizedBox(width: 1),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange),
                          onPressed: () async {
                            try {
                              final data = {
                                'nome': nomeController.text.trim(),
                                'descricao': descricaoController.text.trim(),
                                'preco': double.tryParse(
                                        precoController.text.trim()) ??
                                    0.0,
                                'imagemUrl': imagemUrlController.text.trim(),
                                'atualizado_em': FieldValue.serverTimestamp(),
                              };

                              if (pizzaDoc == null) {
                                data['criado_em'] = FieldValue.serverTimestamp();
                                await FirebaseFirestore.instance
                                    .collection('pizzas')
                                    .add(data);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('pizzas')
                                    .doc(pizzaDoc.id)
                                    .update(data);
                              }

                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao salvar: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class PizzaCard extends StatelessWidget {
  final String nome;
  final String descricao;
  final double preco;
  final String imagemUrl;
  final double? cardHeight;

  const PizzaCard({
    super.key,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagemUrl,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;
    final double effectiveCardHeight = cardHeight != null
        ? cardHeight! + 2
        : (isMobile ? (width / 2) * 1.42 : (width / 3) * 0.92);

    final double imageHeight = effectiveCardHeight * 0.55;
    final double contentHeight = effectiveCardHeight - imageHeight - 26;

    return SizedBox(
      height: effectiveCardHeight,
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: imagemUrl.isNotEmpty
                  ? Image.network(
                      imagemUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (c, e, st) => const Center(
                          child: Icon(Icons.broken_image)),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(
                          child: Icon(Icons.local_pizza, size: 40))),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: contentHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(descricao,
                        style: const TextStyle(fontSize: 12),
                        maxLines: isMobile ? 3 : 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('R\$ ${preco.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
