// lib/services/caixa_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/caixa.dart';

class CaixaService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String get _docIdHoje {
    final agora = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(agora);
  }

  DocumentReference get _caixaRefHoje =>
      firestore.collection('caixa').doc(_docIdHoje);

  Stream<Caixa?> streamCaixaHoje() {
    return _caixaRefHoje.snapshots()
        .map((doc) => doc.exists ? Caixa.fromDoc(doc) : null);
  }

  Future<Caixa?> getCaixaHoje() async {
    final doc = await _caixaRefHoje.get();
    return doc.exists ? Caixa.fromDoc(doc) : null;
  }

  /// Mantém apenas a criação do caixa do dia para fins administrativos.
  Future<Caixa> criarOuObterCaixaDoDia({double saldoInicial = 0.0}) async {
    final doc = await _caixaRefHoje.get();

    if (doc.exists) {
      return Caixa.fromDoc(doc);
    }

    final hojeLocal = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final agora = Timestamp.now();

    final novoCaixa = {
      'data': Timestamp.fromDate(hojeLocal),
      'abertura': agora,
      'fechamento': null,
      'saldo_inicial': saldoInicial,
      'saldo_final': saldoInicial,
      'total_entradas': 0.0,
      'total_saidas': 0.0,
      'fechado': false,
      'movimentos': [],
    };

    await _caixaRefHoje.set(novoCaixa);

    return Caixa(
      id: _docIdHoje,
      data: hojeLocal,
      abertura: agora,
      fechamento: null, // ✅ adicionado
      saldoInicial: saldoInicial,
      saldoFinal: saldoInicial,
      totalEntradas: 0.0,
      totalSaidas: 0.0,
      fechado: false,
      movimentos: [],
    );
  }
}
