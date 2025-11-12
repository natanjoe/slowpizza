import * as functions from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = getFirestore();

async function getSchema(collectionRef, depth = 0) {
  const schema = {};
  const snapshot = await collectionRef.limit(5).get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    for (const [field, value] of Object.entries(data)) {
      const tipo =
        Array.isArray(value) ? "array" :
        value === null ? "null" :
        typeof value;
      schema[field] = schema[field] || tipo;
    }

    // busca subcoleções
    const subcollections = await doc.ref.listCollections();
    for (const sub of subcollections) {
      schema[`sub_${sub.id}`] = await getSchema(sub, depth + 1);
    }
  }

  return schema;
}

export const exportSchema = functions.https.onRequest(async (req, res) => {
  const rootCollections = await db.listCollections();
  const fullSchema = {};

  for (const col of rootCollections) {
    console.log(`📂 Lendo coleção: ${col.id}`);
    fullSchema[col.id] = await getSchema(col);
  }

  res.json(fullSchema);
});
