import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addPizza(String nome, double preco) async {
    try {
      await _db.collection('pizzas').add({
        'nome': nome,
        'preco': preco,
        'createdAt': DateTime.now(),
      });
      print("✅ Pizza adicionada!");
    } catch (e) {
      print("❌ Erro ao adicionar pizza: $e");
    }
  }
}
