/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// ======================
// 1️⃣ Pedidos
// ======================

// Criar pedido
exports.criarPedido = functions.https.onCall(async (data, context) => {
    const pedidoData = {
        id_cliente: db.doc(`clientes/${data.id_cliente}`),
        status: 'recebido',
        tipo_pedido: data.tipo_pedido,
        total: data.total,
        criado_em: admin.firestore.Timestamp.now()
    };

    const pedidoRef = await db.collection('pedidos').add(pedidoData);

    // Criar subcoleção de itens
    const itens = data.itens || [];
    const batch = db.batch();
    itens.forEach(item => {
        const itemRef = pedidoRef.collection('itens').doc();
        batch.set(itemRef, item);
    });
    await batch.commit();

    return { id: pedidoRef.id };
});

// Atualizar status do pedido
exports.atualizarStatusPedido = functions.https.onCall(async (data, context) => {
    const pedidoRef = db.collection('pedidos').doc(data.pedidoId);
    await pedidoRef.update({ status: data.status });
    
    // Criar notificação se pedido estiver pronto
    if (data.status === 'pronto') {
        await db.collection('notificacoes').add({
            data_envio: admin.firestore.Timestamp.now(),
            mensagem: `Pedido #${data.pedidoId} está pronto para retirada.`,
            tipo: 'pedido_status'
        });
    }

    return { success: true };
});

// ======================
// 2️⃣ Vendas
// ======================

exports.registrarVenda = functions.https.onCall(async (data, context) => {
    const vendaData = {
        criado_em: admin.firestore.Timestamp.now(),
        data_venda: admin.firestore.Timestamp.fromDate(new Date(data.data_venda)),
        descontos: data.descontos || 0,
        forma_pagamento: data.forma_pagamento,
        itens: data.itens,
        pedido_id: db.doc(`pedidos/${data.pedido_id}`),
        recebido_por: data.recebido_por,
        taxas: data.taxas || 0,
        tipo_pedido: data.tipo_pedido,
        valor_bruto: data.valor_bruto,
        valor_liquido: data.valor_liquido
    };

    const vendaRef = await db.collection('vendas').add(vendaData);

    // Atualizar estoque
    const batch = db.batch();
    data.itens.forEach(item => {
        const sku = item.id_pizza; // Considerando pizza_id como SKU
        const estoqueRef = db.collection('estoque').doc(sku);
        batch.update(estoqueRef, {
            quantidade_atual: admin.firestore.FieldValue.increment(-item.quantidade)
        });
    });
    await batch.commit();

    return { id: vendaRef.id };
});

// ======================
// 3️⃣ Compras
// ======================

exports.registrarCompra = functions.https.onCall(async (data, context) => {
    const compraData = {
        criado_em: admin.firestore.Timestamp.now(),
        data_compra: admin.firestore.Timestamp.fromDate(new Date(data.data_compra)),
        forma_pagamento: data.forma_pagamento,
        fornecedor_id: db.doc(`fornecedores/${data.fornecedor_id}`),
        frete: data.frete || 0,
        impostos: data.impostos || 0,
        numero_nota: data.numero_nota,
        status: data.status || 'pendente',
        valor_total: data.valor_total
    };

    const compraRef = await db.collection('compras').add(compraData);

    // Criar subcoleção itens
    const batch = db.batch();
    (data.itens || []).forEach(item => {
        const itemRef = compraRef.collection('itens').doc();
        batch.set(itemRef, item);
    });
    await batch.commit();

    // Atualizar estoque
    const batchEstoque = db.batch();
    (data.itens || []).forEach(item => {
        const estoqueRef = db.collection('estoque').doc(item.produto);
        batchEstoque.update(estoqueRef, {
            quantidade_atual: admin.firestore.FieldValue.increment(item.quantidade)
        });
    });
    await batchEstoque.commit();

    return { id: compraRef.id };
});

// ======================
// 4️⃣ Clientes, Fornecedores e Funcionários
// ======================

// Exemplo: criar cliente
exports.criarCliente = functions.https.onCall(async (data, context) => {
    const clienteRef = await db.collection('clientes').add({
        nome: data.nome,
        email: data.email,
        telefone: data.telefone,
        endereco: data.endereco,
        criado_em: admin.firestore.Timestamp.now()
    });
    return { id: clienteRef.id };
});

// ======================
// 5️⃣ Estoque
// ======================

// Atualização automática de estoque já incluída nas funções de vendas e compras

// ======================
// 6️⃣ Financeiro (contas a pagar/receber e relatórios)
// ======================

// Criar conta a pagar
exports.criarContaPagar = functions.https.onCall(async (data, context) => {
    const contaRef = await db.collection('contas_pagar').add({
        criado_em: admin.firestore.Timestamp.now(),
        descricao: data.descricao,
        valor: data.valor,
        data_vencimento: admin.firestore.Timestamp.fromDate(new Date(data.data_vencimento)),
        pago: data.pago || false,
        categoria: data.categoria,
        periodicidade: data.periodicidade
    });
    return { id: contaRef.id };
});

// Criar conta a receber
exports.criarContaReceber = functions.https.onCall(async (data, context) => {
    const contaRef = await db.collection('contas_receber').add({
        criado_em: admin.firestore.Timestamp.now(),
        descricao: data.descricao,
        valor: data.valor,
        data_vencimento: admin.firestore.Timestamp.fromDate(new Date(data.data_vencimento)),
        recebido: data.recebido || false,
        cliente_id: db.doc(`clientes/${data.cliente_id}`)
    });
    return { id: contaRef.id };
});

// Gerar relatório financeiro (exemplo)
exports.gerarRelatorioFinanceiro = functions.https.onCall(async (data, context) => {
    const relatorioRef = await db.collection('relatorios_financeiros').add({
        criado_em: admin.firestore.Timestamp.now(),
        periodo: admin.firestore.Timestamp.fromDate(new Date(data.periodo)),
        total_vendas: data.total_vendas,
        total_custos: data.total_custos,
        despesas_operacionais: data.despesas_operacionais,
        lucro_bruto: data.lucro_bruto,
        lucro_liquido: data.lucro_liquido
    });
    return { id: relatorioRef.id };
});

// ======================
// 7️⃣ Notificações
// ======================

exports.enviarNotificacao = functions.https.onCall(async (data, context) => {
    const notifRef = await db.collection('notificacoes').add({
        data_envio: admin.firestore.Timestamp.now(),
        mensagem: data.mensagem,
        tipo: data.tipo
    });
    return { id: notifRef.id };
});

// ======================
// 8️⃣ Pizzas e Receitas
// ======================

exports.criarPizza = functions.https.onCall(async (data, context) => {
    const pizzaRef = await db.collection('pizzas').add({
        nome: data.nome,
        descricao: data.descricao,
        preco: data.preco,
        disponivel: data.disponivel,
        imagemUrl: data.imagemUrl,
        criado_em: admin.firestore.Timestamp.now()
    });
    return { id: pizzaRef.id };
});

exports.criarReceita = functions.https.onCall(async (data, context) => {
    const receitaRef = await db.collection('receitas').add({
        pizza_id: data.pizza_id,
        ingredientes: data.ingredientes
    });
    return { id: receitaRef.id };
});
