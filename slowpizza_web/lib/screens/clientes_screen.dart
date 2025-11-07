import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _buscaController = TextEditingController();
  String filtroBusca = '';

  Stream<QuerySnapshot> getClientesStream() {
    final collection = FirebaseFirestore.instance.collection('clientes');
    if (filtroBusca.isEmpty) {
      return collection.orderBy('nome').snapshots();
    } else {
      return collection
          .where('nome_busca', isGreaterThanOrEqualTo: filtroBusca.toLowerCase())
          .where('nome_busca', isLessThan: '${filtroBusca.toLowerCase()}z')
          .orderBy('nome_busca')
          .snapshots();
    }
  }

  Future<void> adicionarOuEditarCliente({DocumentSnapshot? cliente}) async {
    final nomeController = TextEditingController(
        text: cliente != null ? cliente['nome'] ?? '' : '');
    final telefoneController = TextEditingController(
        text: cliente != null ? cliente['telefone'] ?? '' : '');
    final enderecoController = TextEditingController(
        text: cliente != null ? cliente['endereco'] ?? '' : '');
    final observacoesController = TextEditingController(
        text: cliente != null ? cliente['observacoes'] ?? '' : '');

    final isEditando = cliente != null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditando ? 'Editar Cliente' : 'Novo Cliente'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: telefoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: enderecoController,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: observacoesController,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
            ),
          ),
          actions: [
            if (isEditando)
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Excluir cliente'),
                      content: const Text(
                          'Tem certeza que deseja excluir este cliente?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            child: const Text('Excluir')),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    await FirebaseFirestore.instance
                        .collection('clientes')
                        .doc(cliente!.id)
                        .delete();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                final telefone = telefoneController.text.trim();
                if (nome.isEmpty) return;

                final dados = {
                  'nome': nome,
                  'nome_busca': nome.toLowerCase(),
                  'telefone': telefone,
                  'endereco': enderecoController.text.trim(),
                  'observacoes': observacoesController.text.trim(),
                  'criado_em': FieldValue.serverTimestamp(),
                };

                final collection =
                    FirebaseFirestore.instance.collection('clientes');

                if (isEditando) {
                  await collection.doc(cliente!.id).update(dados);
                } else {
                  await collection.add(dados);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEditando ? 'Salvar' : 'Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                labelText: 'Buscar cliente',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      filtroBusca = _buscaController.text.trim();
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  filtroBusca = value.trim();
                });
              },
            ),
          ),

          // Lista de clientes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getClientesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Erro ao carregar clientes'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clientes = snapshot.data!.docs;

                if (clientes.isEmpty) {
                  return const Center(
                    child: Text('Nenhum cliente cadastrado'),
                  );
                }

                return ListView.builder(
                  itemCount: clientes.length,
                  itemBuilder: (context, index) {
                    final cliente = clientes[index];
                    final data = cliente.data() as Map<String, dynamic>;

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.shade100,
                          child: Text(
                            (data['nome'] ?? '?')
                                .toString()
                                .characters
                                .first
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(data['nome'] ?? 'Sem nome'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['telefone'] != null &&
                                data['telefone'].toString().isNotEmpty)
                              Text('📞 ${data['telefone']}'),
                            if (data['endereco'] != null &&
                                data['endereco'].toString().isNotEmpty)
                              Text('🏠 ${data['endereco']}'),
                          ],
                        ),
                        onTap: () => adicionarOuEditarCliente(cliente: cliente),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Botão flutuante para adicionar novo cliente
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange, // 🍕 mesma cor da tela de pizzas
        onPressed: () => adicionarOuEditarCliente(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
