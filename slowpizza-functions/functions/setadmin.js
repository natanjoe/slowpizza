const admin = require("firebase-admin");

// Caminho para o arquivo da service account
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = "TcZTpdMO1bQqSdfjueIrr16oB792"; // seu usuário admin

async function setAdmin() {
  try {
    await admin.auth().setCustomUserClaims(uid, { role: "admin" });
    console.log("✅ Admin definido com sucesso!");
    process.exit(0);
  } catch (error) {
    console.error("❌ Erro ao definir admin:", error);
    process.exit(1);
  }
}

setAdmin();
