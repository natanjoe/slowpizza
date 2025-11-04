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
        title: const Text('Pizzas'),
      ),
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

              return GestureDetector(
                onTap: () => _showPizzaForm(context, pizzaDoc: pizzas[index]),
                child: PizzaCard(
                  nome: pizzaData['nome'] ?? 'Sem nome',
                  descricao: pizzaData['descricao'] ?? 'Sem descrição',
                  preco: (pizzaData['preco'] is num)
                      ? pizzaData['preco'].toDouble()
                      : 0.0,
                  imagemUrl: (pizzaData['imagemUrl'] ?? '').toString(),
                ),
              );
            },
          );
        },
      ),
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

    _imagemSelecionada = null;
    _imagemNome = null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          Future<void> _pickImage() async {
            FilePickerResult? result = await FilePicker.platform
                .pickFiles(type: FileType.image, withData: true);
            if (result != null && result.files.first.bytes != null) {
              setModalState(() {
                _imagemSelecionada = result.files.first.bytes!;
                _imagemNome = result.files.first.name;
              });
            }
          }

          Future<void> _confirmDelete() async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirmar exclusão'),
                content: const Text('Deseja realmente excluir esta pizza?'),
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
                    const SnackBar(content: Text('Pizza excluída com sucesso')),
                  );
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
                const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pizzaDoc == null ? 'Adicionar Pizza' : 'Editar Pizza',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                          child: const Center(
                                              child: Icon(Icons.add_a_photo,
                                                  size: 40)),
                                        ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: nomeController,
                              decoration: const InputDecoration(
                                  labelText: 'Nome da Pizza'),
                            ),
                            TextField(
                              controller: descricaoController,
                              decoration: const InputDecoration(
                                  labelText: 'Descrição'),
                              maxLines: 3,
                            ),
                            TextField(
                              controller: precoController,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Preço'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (pizzaDoc != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: _confirmDelete,
                            icon: const Icon(Icons.delete),
                            label: const Text('Excluir'),
                          ),
                        TextButton(
                          onPressed: () {
                            _imagemSelecionada = null;
                            _imagemNome = null;
                            Navigator.pop(context);
                          },
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                          ),
                          onPressed: () async {
                            try {
                              String? url = imagemUrl;

                              if (_imagemSelecionada != null &&
                                  _imagemNome != null) {
                                final ref = FirebaseStorage.instance
                                    .ref()
                                    .child('pizzas/$_imagemNome');
                                await ref.putData(_imagemSelecionada!);
                                url = await ref.getDownloadURL();
                              }

                              final pizzaData = {
                                'nome': nomeController.text.trim(),
                                'descricao':
                                    descricaoController.text.trim(),
                                'preco': double.tryParse(
                                        precoController.text.trim()) ??
                                    0.0,
                                'imagemUrl': url ?? '',
                                'atualizado_em': FieldValue.serverTimestamp(),
                              };

                              if (pizzaDoc == null) {
                                pizzaData['criado_em'] =
                                    FieldValue.serverTimestamp();
                                await FirebaseFirestore.instance
                                    .collection('pizzas')
                                    .add(pizzaData);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('pizzas')
                                    .doc(pizzaDoc.id)
                                    .update(pizzaData);
                              }

                              _imagemSelecionada = null;
                              _imagemNome = null;
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Erro ao salvar: $e')));
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

    _imagemSelecionada = null;
    _imagemNome = null;
  }
}

class PizzaCard extends StatelessWidget {
  final String nome;
  final String descricao;
  final double preco;
  final String imagemUrl;

  const PizzaCard({
    super.key,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagemUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
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
                    ? Image.network(imagemUrl,
                        fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.local_pizza, size: 40),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(nome,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'R\$ ${preco.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
