/**
 * Script para listar todas as coleções e campos do Firestore
 * e gerar um arquivo schema.json
 */

import fs from "fs";
import { initializeApp, applicationDefault, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// 🔧 Caminho da sua chave de serviço (baixe do Firebase Console > Configurações > Contas de serviço)
import serviceAccount from "./serviceAccountKey.json" assert { type: "json" };

// Inicializa o Firebase Admin
initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function getSchema(collectionRef, depth = 0) {
  const schema = {};
  const snapshot = await collectionRef.limit(5).get(); // lê até 5 docs pra inferir campos
  for (const doc of snapshot.docs) {
    const data = doc.data();
    for (const [field, value] of Object.entries(data)) {
      const tipo =
        Array.isArray(value) ? "array" :
        value === null ? "null" :
        typeof value;
      schema[field] = schema[field] || tipo;
    }
  }

  // busca subcoleções (recursivo)
  for (const doc of snapshot.docs) {
    const subcollections = await doc.ref.listCollections();
    for (const sub of subcollections) {
      schema[`sub_${sub.id}`] = await getSchema(sub, depth + 1);
    }
  }

  return schema;
}

async function main() {
  const rootCollections = await db.listCollections();
  const fullSchema = {};

  for (const col of rootCollections) {
    console.log(`📂 Lendo coleção: ${col.id}`);
    fullSchema[col.id] = await getSchema(col);
  }

  fs.writeFileSync("schema.json", JSON.stringify(fullSchema, null, 2));
  console.log("✅ Schema salvo em schema.json");
}

main().catch(console.error);
