import admin from "firebase-admin";
import fs from "fs";

// =========================
// 1. Credencial Firebase
// =========================
const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccountKey.json", "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();


// ========================================================
// FUNÇÃO PARA NORMALIZAR O FORMATO DO DOCUMENTO DO CAIXA
// ========================================================
function normalizarDocumentoCaixa(doc) {

  const data = doc.data();

  const movimentosConvertidos = [];

  // Caso os movimentos sejam strings → converter para objetos vazios
  if (Array.isArray(data.movimentos)) {
    for (const entry of data.movimentos) {
      if (typeof entry === "string") {
        movimentosConvertidos.push({
          timestamp: new Date(),
          tipo: "entrada",
          origem: "ajuste_migracao",
          descricao: entry,
          valor: 0
        });
      } else {
        movimentosConvertidos.push(entry);
      }
    }
  }

  return {
    data: data.data || new Date(),
    criado_em: data.criado_em || new Date(),

    abertura: data.abertura || {
      operador: "migracao",
      valor: data.saldo_inicial || 0
    },

    fechamento: data.fechamento || {
      operador: data.fechado_por || "migracao",
      valor: data.saldo_fechamento || 0
    },

    saldo_inicial: data.saldo_inicial || 0,
    saldo_final: data.saldo_final || data.saldo_fechamento || 0,

    movimentos: movimentosConvertidos
  };
}


// ========================================================
//  MIGRAR DOCUMENTO ANTIGO → NOVO DOCUMENTO YYYY-MM-DD
// ========================================================
function gerarIdData(timestamp) {
  const d = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}


// ========================================================
// PROCESSAR TODOS OS DOCUMENTOS
// ========================================================
async function migrarCaixa() {
  console.log("📦 Iniciando migração da coleção CAIXA...");

  const snapshot = await db.collection("caixa").get();

  for (const doc of snapshot.docs) {
    const oldId = doc.id;
    const data = doc.data();

    const newId = gerarIdData(data.data || new Date());

    console.log(`➡ Migrando documento ${oldId} → ${newId}`);

    const novoDocumento = normalizarDocumentoCaixa(doc);

    // salva novo
    await db.collection("caixa").doc(newId).set(novoDocumento);

    // remove antigo
    if (oldId !== newId) {
      await db.collection("caixa").doc(oldId).delete();
      console.log(`🗑 Documento antigo ${oldId} removido.`);
    }
  }

  console.log("\n🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO!");
}

migrarCaixa();
