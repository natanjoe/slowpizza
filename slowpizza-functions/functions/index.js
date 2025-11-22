// functions/index.js - VERSÃO 2025 - 100% V2 - FUNCIONA COM FLUTTER WEB
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
// Inicializa o Admin SDK (uma única vez)
admin.initializeApp();
const db = admin.firestore();

// ======================
// 1️⃣ PEDIDOS
// ======================
exports.criarPedido = onCall({ region: "us-central1" }, async (request) => {
  const data = request.data;
  const pedidoData = {
    id_cliente: db.doc(`clientes/${data.id_cliente}`),
    status: "recebido",
    tipo_pedido: data.tipo_pedido,
    total: data.total,
    criado_em: admin.firestore.FieldValue.serverTimestamp(),
  };
  const pedidoRef = await db.collection("pedidos").add(pedidoData);
  const batch = db.batch();
  (data.itens || []).forEach((item) => {
    const itemRef = pedidoRef.collection("itens").doc();
    batch.set(itemRef, item);
  });
  await batch.commit();
  return { id: pedidoRef.id };
});

exports.atualizarStatusPedido = onCall({ region: "us-central1" }, async (request) => {
  const { pedidoId, status } = request.data;
  const pedidoRef = db.collection("pedidos").doc(pedidoId);
  await pedidoRef.update({ status });
  if (status === "pronto") {
    await db.collection("notificacoes").add({
      data_envio: admin.firestore.FieldValue.serverTimestamp(),
      mensagem: `Pedido #${pedidoId} está pronto para retirada.`,
      tipo: "pedido_status",
    });
  }
  return { success: true };
});

// ======================
// 2️⃣ REGISTRAR VENDA – VERSÃO CENTRALIZADA NO SERVIDOR
// ======================
exports.registrarVenda = onCall({ region: "us-central1" }, async (request) => {
  const data = request.data || {};
  console.log("📥 registrarVenda chamada:", JSON.stringify(data));

  try {
    if (!data.pedidoId) throw new HttpsError("invalid-argument", "pedidoId obrigatório");
    if (!Array.isArray(data.itens) || data.itens.length === 0)
      throw new HttpsError("invalid-argument", "itens obrigatório");

    const valorLiquido = Number(data.valorLiquido || data.valorBruto || 0);
    const valorBruto = Number(data.valorBruto || valorLiquido);
    const descontos = Number(data.descontos || 0);
    const taxas = Number(data.taxas || 0);
    const formaPagamento = data.formaPagamento || "não informado";

    // ---------------------------
    // 1. REFERÊNCIA DO CAIXA DO DIA
    // ---------------------------
    const hojeLocal = new Date();
    hojeLocal.setHours(0, 0, 0, 0);
    const docIdCaixa = hojeLocal.toISOString().slice(0, 10); // yyyy-MM-dd
    const caixaRef = db.collection("caixa").doc(docIdCaixa);

    const caixaSnap = await caixaRef.get();

    if (!caixaSnap.exists) {
      console.log("🔥 Criando CAIXA do dia automaticamente:", docIdCaixa);
      await caixaRef.set({
        data: admin.firestore.Timestamp.fromDate(hojeLocal),
        abertura: admin.firestore.FieldValue.serverTimestamp(),
        fechamento: null,
        saldo_inicial: 0,
        saldo_final: 0,
        total_entradas: 0,
        total_saidas: 0,
        fechado: false,
        fechado_por: null,
        movimentos: [],
        criado_em: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const batch = db.batch();

    // ---------------------------
    // 2. Criar VENDA
    // ---------------------------
    const vendaRef = db.collection("vendas").doc();
    batch.set(vendaRef, {
      pedido_id: db.doc(`pedidos/${data.pedidoId}`),
      pedidoId: data.pedidoId,
      tipo_pedido: data.tipoPedido || "balcao",
      data_venda: admin.firestore.FieldValue.serverTimestamp(),
      valor_bruto: valorBruto,
      descontos: descontos,
      taxas: taxas,
      valor_liquido: valorLiquido,
      forma_pagamento: formaPagamento,
      recebido_por: data.recebidoPor || "caixa",
      itens: data.itens,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ---------------------------
    // 3. Atualiza pedido como pago
    // ---------------------------
    const pedidoRef = db.collection("pedidos").doc(data.pedidoId);
    batch.update(pedidoRef, {
      status: "pago",
      pago_em: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ---------------------------
    // 4. Baixa de estoque
    // ---------------------------
    for (const item of data.itens) {
      const pizzaId = item.id_pizza || item.pizzaId || item.pizzaId1;
      const qtd = Number(item.quantidade || 1);
      if (!pizzaId) continue;

      const receitaSnap = await db.collection("receitas")
        .where("pizza_id", "==", pizzaId)
        .limit(1)
        .get();

      if (receitaSnap.empty) continue;

      const ingredientes = receitaSnap.docs[0].data().ingredientes || [];

      for (const ing of ingredientes) {
        const ingId = ing.id || ing.produto_id || ing.sku;
        const qtdPorPizza = Number(ing.quantidade || 0);
        if (!ingId || qtdPorPizza === 0) continue;

        const totalUsado = qtdPorPizza * qtd;
        const ingRef = db.collection("estoque").doc(String(ingId));
        batch.update(ingRef, {
          quantidade_atual: admin.firestore.FieldValue.increment(-totalUsado),
        });
      }
    }

    // ---------------------------
    // 5. REGISTRAR MOVIMENTO NO CAIXA
    // ---------------------------
    const movimento = {
      tipo: "entrada",
      valor: valorLiquido,
      descricao: `Venda #${vendaRef.id} - ${formaPagamento}`,
      timestamp: admin.firestore.Timestamp.now(),
      origem: "venda",
      venda_id: vendaRef.id,
    };

    batch.update(caixaRef, {
      movimentos: admin.firestore.FieldValue.arrayUnion(movimento),
      total_entradas: admin.firestore.FieldValue.increment(valorLiquido),
      saldo_final: admin.firestore.FieldValue.increment(valorLiquido),
    });

    // ---------------------------
    // 6. Commit final
    // ---------------------------
    await batch.commit();

    console.log("🟢 Venda criada com sucesso ID:", vendaRef.id);

    return {
      success: true,
      vendaId: vendaRef.id,
      valor_liquido: valorLiquido,
      forma_pagamento: formaPagamento,
    };

  } catch (err) {
    console.error("❌ Erro em registrarVenda:", err);
    throw err instanceof HttpsError
      ? err
      : new HttpsError("internal", err.message);
  }
});




// ======================
// 3️⃣ COMPRAS
// ======================
exports.registrarCompra = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;

    const compraRef = await db.collection("compras").add({
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
      data_compra: admin.firestore.Timestamp.fromDate(new Date(data.data_compra)),
      forma_pagamento: data.forma_pagamento,
      fornecedor_id: db.doc(`fornecedores/${data.fornecedor_id}`),
      frete: data.frete || 0,
      impostos: data.impostos || 0,
      numero_nota: data.numero_nota,
      status: data.status || "pendente",
      valor_total: data.valor_total,
    });

    // Itens da compra
    const batchItens = db.batch();
    (data.itens || []).forEach((item) => {
      const itemRef = compraRef.collection("itens").doc();
      batchItens.set(itemRef, item);
    });
    await batchItens.commit();

    // Atualiza estoque
    const batchEstoque = db.batch();
    (data.itens || []).forEach((item) => {
      const estoqueRef = db.collection("estoque").doc(item.produto);
      batchEstoque.update(estoqueRef, {
        quantidade_atual: admin.firestore.FieldValue.increment(item.quantidade),
      });
    });
    await batchEstoque.commit();

    return { id: compraRef.id };
  }
);

// ======================
// 4️⃣ CLIENTES
// ======================
exports.criarCliente = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("clientes").add({
      nome: data.nome,
      email: data.email,
      telefone: data.telefone,
      endereco: data.endereco,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  }
);

// ======================
// 5️⃣ CONTAS A PAGAR / RECEBER
// ======================
exports.criarContaPagar = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("contas_pagar").add({
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
      descricao: data.descricao,
      valor: data.valor,
      data_vencimento: admin.firestore.Timestamp.fromDate(new Date(data.data_vencimento)),
      pago: data.pago || false,
      categoria: data.categoria,
      periodicidade: data.periodicidade,
    });
    return { id: ref.id };
  }
);

exports.criarContaReceber = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("contas_receber").add({
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
      descricao: data.descricao,
      valor: data.valor,
      data_vencimento: admin.firestore.Timestamp.fromDate(new Date(data.data_vencimento)),
      recebido: data.recebido || false,
      cliente_id: db.doc(`clientes/${data.cliente_id}`),
    });
    return { id: ref.id };
  }
);

// ======================
// 6️⃣ RELATÓRIOS / NOTIFICAÇÕES / PIZZAS
// ======================
exports.gerarRelatorioFinanceiro = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("relatorios_financeiros").add({
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
      periodo: admin.firestore.Timestamp.fromDate(new Date(data.periodo)),
      total_vendas: data.total_vendas,
      total_custos: data.total_custos,
      despesas_operacionais: data.despesas_operacionais,
      lucro_bruto: data.lucro_bruto,
      lucro_liquido: data.lucro_liquido,
    });
    return { id: ref.id };
  }
);

exports.enviarNotificacao = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("notificacoes").add({
      data_envio: admin.firestore.FieldValue.serverTimestamp(),
      mensagem: data.mensagem,
      tipo: data.tipo,
    });
    return { id: ref.id };
  }
);

exports.criarPizza = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("pizzas").add({
      nome: data.nome,
      descricao: data.descricao,
      preco: data.preco,
      disponivel: data.disponivel,
      imagemUrl: data.imagemUrl,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  }
);

exports.criarReceita = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const ref = await db.collection("receitas").add({
      pizza_id: data.pizza_id,
      ingredientes: data.ingredientes,
    });
    return { id: ref.id };
  }
);