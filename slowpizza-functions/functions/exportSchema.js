import admin from "firebase-admin";
import fs from "fs";

const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccountKey.json", "utf8")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function getSchema(collectionRef, depth = 0) {
  const schema = {};
  const snapshot = await collectionRef.limit(5).get();

  for (const doc of snapshot.docs) {
    const data = doc.data();

    for (const [field, value] of Object.entries(data)) {
      if (Array.isArray(value)) {
        schema[field] = schema[field] || { type: "array", items: {} };

        // Se o array tiver elementos, inferir estrutura
        if (value.length > 0) {
          const firstItem = value[0];

          if (typeof firstItem === "object" && firstItem !== null) {
            // Array de objetos
            for (const [subField, subValue] of Object.entries(firstItem)) {
              schema[field].items[subField] =
                Array.isArray(subValue)
                  ? "array"
                  : subValue === null
                  ? "null"
                  : typeof subValue;
            }
          } else {
            // Array de valores simples (string, number, bool)
            schema[field].items = typeof firstItem;
          }
        } else {
          schema[field].items = "empty";
        }
      }

      // Campos NÃO array
      else {
        const tipo =
          value === null ? "null" : typeof value;

        schema[field] = schema[field] || tipo;
      }
    }

    // subcoleções
    const subcollections = await doc.ref.listCollections();
    for (const sub of subcollections) {
      schema[`sub_${sub.id}`] = await getSchema(sub, depth + 1);
    }
  }

  return schema;
}


async function exportSchema() {
  const rootCollections = await db.listCollections();
  const fullSchema = {};

  for (const col of rootCollections) {
    console.log(`📂 Lendo coleção: ${col.id}`);
    fullSchema[col.id] = await getSchema(col);
  }

  fs.writeFileSync("schema.json", JSON.stringify(fullSchema, null, 2));
  console.log("✅ Arquivo schema.json gerado com sucesso!");
}

exportSchema();
