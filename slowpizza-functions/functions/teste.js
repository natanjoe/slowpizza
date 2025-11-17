const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.testeVenda = functions.https.onCall(async (data, context) => {
  console.log("TESTE CHAMADO - DADOS:", {
    pedidoId: data.pedidoId,
    valorLiquido: data.valorLiquido,
    itens: data.itens?.length
  });

  return { success: true, mensagem: "TESTE FUNCIONOU!", pedidoId: data.pedidoId };
});