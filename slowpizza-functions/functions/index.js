// functions/index.js - VERSÃO 2025 - 100% V2 - FUNCIONA COM FLUTTER WEB

const { onCall, HttpsError } = require("firebase-functions/v2/https");

const admin = require("firebase-admin");

// Inicializa o Admin SDK (uma única vez)
admin.initializeApp();
const db = admin.firestore();

// ======================
// 1️⃣ PEDIDOS
// ======================
exports.criarPedido = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;

    const pedidoData = {
      id_cliente: db.doc(`clientes/${data.id_cliente}`),
      status: "recebido",
      tipo_pedido: data.tipo_pedido,
      total: data.total,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
    };

    const pedidoRef = await db.collection("pedidos").add(pedidoData);

    // Subcoleção de itens
    const batch = db.batch();
    (data.itens || []).forEach((item) => {
      const itemRef = pedidoRef.collection("itens").doc();
      batch.set(itemRef, item);
    });
    await batch.commit();

    return { id: pedidoRef.id };
  }
);

exports.atualizarStatusPedido = onCall(
  { region: "us-central1" },
  async (request) => {
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
  }
);

// ======================
// 2️⃣ VENDAS - A ESTRELA DO DIA
// ======================
// registrarVenda v2 - ATUALIZA CAIXA DO DIA + BAIXA ESTOQUE DE INGREDIENTES
exports.registrarVenda = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;

    console.log("registrarVenda chamada", data);

    if (!data.pedidoId) throw new HttpsError("invalid-argument", "pedidoId obrigatório");
    if (!data.itens || data.itens.length === 0) throw new HttpsError("invalid-argument", "itens obrigatório");

    const batch = db.batch();
    const hoje = new Date();
    hoje.setHours(0, 0, 0, 0);
    const amanhã = new Date(hoje);
    amanhã.setDate(amanhã.getDate() + 1);

    // 1. Busca ou cria o caixa do dia
    const caixaQuery = await db.collection("caixa")
      .where("data", ">=", admin.firestore.Timestamp.fromDate(hoje))
      .where("data", "<", admin.firestore.Timestamp.fromDate(amanhã))
      .limit(1)
      .get();

    let caixaRef;
    let caixaData = { movimentos: [], saldo_fechamento: 0 };

    if (caixaQuery.empty) {
      // Cria caixa do dia
      caixaRef = db.collection("caixa").doc();
      batch.set(caixaRef, {
        data: admin.firestore.Timestamp.fromDate(hoje),
        abertura: admin.firestore.FieldValue.serverTimestamp(),
        movimentos: [],
        saldo_fechamento: 0,
        fechado_por: null,
        criado_em: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      caixaRef = caixaQuery.docs[0].ref;
      caixaData = caixaQuery.docs[0].data();
    }

    // 2. Cria a venda
    const vendaRef = db.collection("vendas").doc();
    batch.set(vendaRef, {
      pedido_id: db.doc(`pedidos/${data.pedidoId}`),
      pedidoId: data.pedidoId,
      tipo_pedido: data.tipoPedido || "balcao",
      data_venda: admin.firestore.FieldValue.serverTimestamp(),
      valor_bruto: Number(data.valorBruto || data.valorLiquido),
      descontos: Number(data.descontos || 0),
      taxas: Number(data.taxas || 0),
      valor_liquido: Number(data.valorLiquido),
      forma_pagamento: data.formaPagamento,
      recebido_por: data.recebidoPor || "caixa_web",
      itens: data.itens,
      criado_em: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Adiciona movimento no caixa
    const movimento = {
      tipo: "entrada",
      descricao: `Venda #${vendaRef.id.substring(0, 8)} - ${data.formaPagamento}`,
      valor: Number(data.valorLiquido),
      venda_id: vendaRef,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    batch.update(caixaRef, {
      movimentos: admin.firestore.FieldValue.arrayUnion(movimento),
      saldo_fechamento: admin.firestore.FieldValue.increment(Number(data.valorLiquido)),
    });

    // 4. Baixa estoque dos ingredientes (usando receitas)
    for (const item of data.itens) {
      const pizzaId = item.id_pizza || item.pizzaId;
      if (!pizzaId) continue;

      const receitaSnap = await db.collection("receitas")
        .where("pizza_id", "==", pizzaId)
        .limit(1)
        .get();

      if (receitaSnap.empty) continue;

      const ingredientes = receitaSnap.docs[0].data().ingredientes || [];

      for (const ing of ingredientes) {
        const ingRef = db.collection("estoque").doc(ing.id || ing.produto_id);
        const quantidadeUsada = (ing.quantidade || ing.qtd) * (item.quantidade || 1);

        batch.update(ingRef, {
          quantidade_atual: admin.firestore.FieldValue.increment(-quantidadeUsada),
        });
      }
    }

    // Executa tudo de uma vez
    await batch.commit();

    console.log("VENDA + CAIXA + ESTOQUE ATUALIZADOS →", vendaRef.id);
    return { success: true, id: vendaRef.id };
  }
);

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