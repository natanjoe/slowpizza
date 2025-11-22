// lib/services/venda_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendaService {
  final region = 'us-central1';

  Future<String> registrarVenda({
    required String pedidoId,
    required double valorBruto,
    required double valorLiquido,
    required String formaPagamento,
    required String tipoPedido,
    required String recebidoPor,
    required List<Map<String, dynamic>> itens,
    double descontos = 0,
    double taxas = 0,
  }) async {
    try {
      print("📌 Enviando venda para Cloud Function...");

      final payload = {
        "pedidoId": pedidoId,
        "valorBruto": valorBruto,
        "valorLiquido": valorLiquido,
        "formaPagamento": formaPagamento,
        "tipoPedido": tipoPedido,
        "recebidoPor": recebidoPor,
        "itens": itens,
        "descontos": descontos,
        "taxas": taxas,
      };

      final callable = FirebaseFunctions.instanceFor(region: region)
          .httpsCallable('registrarVenda');

      final result = await callable.call(payload);

      print("🟢 Function respondeu: ${result.data}");

      final data = result.data;
      final vendaId = data["vendaId"]?.toString() ?? "";

      if (vendaId.isEmpty) {
        throw Exception("Cloud Function não retornou vendaId");
      }

      print("✅ Venda concluída com sucesso → ID = $vendaId");

      return vendaId;

    } catch (e, st) {
      print("❌ ERRO AO REGISTRAR VENDA: $e\n$st");
      rethrow;
    }
  }
}
