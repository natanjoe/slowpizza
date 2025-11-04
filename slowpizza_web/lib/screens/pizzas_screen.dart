import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

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
      appBar: AppBar(
        title: const Text('Manutenção de Pizzas'),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('pizzas').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const SizedBox();
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final total = snapshot.data!.docs.length;

              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Chip(
                  label: Text(
                    '$total',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.deepOrange,
                ),
              );
            },
          ),
        ],
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pizzas.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 3 / 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final pizzaData =
                  pizzas[index].data() as Map<String, dynamic>? ?? {};

              return PizzaCard(
                nome: pizzaData['nome'] ?? 'Sem nome',
                descricao: pizzaData['descricao'] ?? 'Sem descrição',
                preco: (pizzaData['preco'] is num)
                    ? pizzaData['preco'].toDouble()
                    : 0.0,
                imagemUrl: (pizzaData['imagemUrl'] ?? '').toString(),
                onEdit: () => _showPizzaForm(context, pizzaDoc: pizzas[index]),
                onDelete: () async {
                  await FirebaseFirestore.instance
                      .collection('pizzas')
                      .doc(pizzas[index].id)
                      .delete();
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPizzaForm(context),
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _showPizzaForm(BuildContext context,
      {DocumentSnapshot? pizzaDoc}) async {
    final nomeController = TextEditingController(text: pizzaDoc?['nome'] ?? '');
    final descricaoController =
        TextEditingController(text: pizzaDoc?['descricao'] ?? '');
    final precoController =
        TextEditingController(text: pizzaDoc?['preco']?.toString() ?? '');
    String? imagemUrl = pizzaDoc?['imagemUrl'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            title:
                Text(pizzaDoc == null ? 'Adicionar Pizza' : 'Editar Pizza'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );

                      if (result != null && result.files.first.bytes != null) {
                        setModalState(() {
                          _imagemSelecionada = result.files.first.bytes!;
                          _imagemNome = result.files.first.name;
                        });
                      }
                    },
                    child: _imagemSelecionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _imagemSelecionada!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : (imagemUrl != null && imagemUrl.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imagemUrl,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                height: 160,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(Icons.add_a_photo, size: 40),
                              ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nomeController,
                    decoration:
                        const InputDecoration(labelText: 'Nome da Pizza'),
                  ),
                  TextField(
                    controller: descricaoController,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                  ),
                  TextField(
                    controller: precoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Preço'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                child: const Text('Salvar'),
                onPressed: () async {
                  try {
                    String? url = imagemUrl;

                    if (_imagemSelecionada != null) {
                      final ref = FirebaseStorage.instance
                          .ref()
                          .child('pizzas/$_imagemNome');
                      await ref.putData(_imagemSelecionada!);
                      url = await ref.getDownloadURL();
                    }

                    final pizzaData = {
                      'nome': nomeController.text.trim(),
                      'descricao': descricaoController.text.trim(),
                      'preco':
                          double.tryParse(precoController.text.trim()) ?? 0.0,
                      'imagemUrl': url ?? '',
                      'atualizado_em': FieldValue.serverTimestamp(),
                    };

                    if (pizzaDoc == null) {
                      pizzaData['criado_em'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance
                          .collection('pizzas')
                          .add(pizzaData);
                    } else {
                      await FirebaseFirestore.instance
                          .collection('pizzas')
                          .doc(pizzaDoc.id)
                          .update(pizzaData);
                    }

                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );

    _imagemSelecionada = null;
    _imagemNome = null;
  }
}

class PizzaCard extends StatelessWidget {
  final String nome;
  final String descricao;
  final double preco;
  final String imagemUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PizzaCard({
    super.key,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagemUrl,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imagemUrl.isNotEmpty
                    ? Image.network(imagemUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.local_pizza, size: 40),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nome,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const Spacer(),
            Text(
              'R\$ ${preco.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
