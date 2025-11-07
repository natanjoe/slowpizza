import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MesasScreen extends StatefulWidget {
  const MesasScreen({Key? key}) : super(key: key);

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _adicionarOuEditarMesa({DocumentSnapshot? mesa}) async {
    final TextEditingController numeroController =
        TextEditingController(text: mesa?['numero'] ?? '');
    final TextEditingController descricaoController =
        TextEditingController(text: mesa?['descricao'] ?? '');
    String status = mesa?['status'] ?? 'Livre';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            mesa == null ? 'Adicionar Mesa' : 'Editar Mesa',
            style: AppTextStyles.heading,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Número da Mesa',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(
                        value: 'Livre', child: Text('Livre')),
                    DropdownMenuItem(
                        value: 'Ocupada', child: Text('Ocupada')),
                    DropdownMenuItem(
                        value: 'Reservada', child: Text('Reservada')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        status = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
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
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                mesa == null ? 'Salvar' : 'Atualizar',
                style: AppTextStyles.button,
              ),
              onPressed: () async {
                if (numeroController.text.trim().isEmpty) return;

                if (mesa == null) {
                  await _firestore.collection('mesas').add({
                    'numero': numeroController.text.trim(),
                    'descricao': descricaoController.text.trim(),
                    'status': status,
                  });
                } else {
                  await _firestore
                      .collection('mesas')
                      .doc(mesa.id)
                      .update({
                    'numero': numeroController.text.trim(),
                    'descricao': descricaoController.text.trim(),
                    'status': status,
                  });
                }

                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirMesa(String id) async {
    await _firestore.collection('mesas').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('mesas').orderBy('numero').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar mesas'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final mesas = snapshot.data!.docs;

          if (mesas.isEmpty) {
            return const Center(child: Text('Nenhuma mesa cadastrada.'));
          }

          return ListView.builder(
            itemCount: mesas.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final mesa = mesas[index];
              final numero = mesa['numero'] ?? '';
              final descricao = mesa['descricao'] ?? '';
              final status = mesa['status'] ?? 'Livre';

              Color statusColor;
              switch (status) {
                case 'Ocupada':
                  statusColor = Colors.redAccent;
                  break;
                case 'Reservada':
                  statusColor = Colors.orangeAccent;
                  break;
                default:
                  statusColor = Colors.green;
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(
                    'Mesa $numero',
                    style: AppTextStyles.subheading,
                  ),
                  subtitle: Text(
                    descricao.isEmpty ? 'Sem descrição' : descricao,
                    style: AppTextStyles.body,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () =>
                            _adicionarOuEditarMesa(mesa: mesa),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _excluirMesa(mesa.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _adicionarOuEditarMesa(),
      ),
    );
  }
}
