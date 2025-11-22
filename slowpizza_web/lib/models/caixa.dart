// lib/models/caixa.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Movimento {
  final String tipo;
  final double valor;
  final String descricao;
  final DateTime timestamp;
  final String origem;
  final DocumentReference? vendaId;

  Movimento({
    required this.tipo,
    required this.valor,
    required this.descricao,
    required this.timestamp,
    required this.origem,
    this.vendaId,
  });

  factory Movimento.fromMap(Map<String, dynamic> map) {
    return Movimento(
      tipo: map['tipo'],
      valor: (map['valor'] ?? 0).toDouble(),
      descricao: map['descricao'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      origem: map['origem'] ?? '',
      vendaId: map['venda_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'valor': valor,
      'descricao': descricao,
      'timestamp': Timestamp.fromDate(timestamp),
      'origem': origem,
      'venda_id': vendaId,
    };
  }
}

class Caixa {
  final String id;
  final DateTime data;
  final Timestamp? abertura;
  final Timestamp? fechamento;
  final double saldoInicial;
  final double saldoFinal;
  final double totalEntradas;
  final double totalSaidas;
  final bool fechado;
  final List<Movimento> movimentos;

  Caixa({
    required this.id,
    required this.data,
    required this.abertura,
    required this.fechamento,
    required this.saldoInicial,
    required this.saldoFinal,
    required this.totalEntradas,
    required this.totalSaidas,
    required this.fechado,
    required this.movimentos,
  });

  factory Caixa.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final movimentosList = (data['movimentos'] as List<dynamic>? ?? [])
        .map((m) => Movimento.fromMap(m))
        .toList();

    return Caixa(
      id: doc.id,
      data: (data['data'] as Timestamp).toDate(),
      abertura: data['abertura'],
      fechamento: data['fechamento'],
      saldoInicial: (data['saldo_inicial'] ?? 0).toDouble(),
      saldoFinal: (data['saldo_final'] ?? 0).toDouble(),
      totalEntradas: (data['total_entradas'] ?? 0).toDouble(),
      totalSaidas: (data['total_saidas'] ?? 0).toDouble(),
      fechado: data['fechado'] ?? false,
      movimentos: movimentosList,
    );
  }
}
