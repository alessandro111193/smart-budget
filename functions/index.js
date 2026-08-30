const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { GoogleGenerativeAI } = require("@google/generative-ai");

initializeApp();
const db = getFirestore();

exports.chatWithAssistant = onCall({ timeoutSeconds: 120 }, async (request) => {
  try {
    const apiKey = process.env.GEMINI_API_KEY || "chiave_token_gemini";
    const genAI = new GoogleGenerativeAI(apiKey);

    // 1. Gestione utente
    const userId = request.auth ? request.auth.uid : "utente_test_locale";
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // 2. Verifica accesso Premium/Trial
    const isPremium = userData.isPremium === true;
    const trialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;
    const isTrialActive = trialEnd && trialEnd > new Date();

    // 3. Verifica limite trial LATO SERVER
    const richiesteUsate = userData.richiesteAiUsate || 0;
    if (!isPremium && !isTrialActive && richiesteUsate >= 50) {
      throw new HttpsError(
          "resource-exhausted",
          "Hai raggiunto il limite di richieste AI del trial.",
      );
    }

    // 4. Costruisci il contesto e chiama Gemini
    const question = request.data.question;
    const summary = request.data.spendingSummary || "";

    const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash-lite" });
    const prompt = `Sei un assistente di budget familiare. 
Rispondi in italiano, in modo breve e concreto.
Dati di riepilogo dell'utente: ${summary}
Domanda: ${question}`;

    const result = await model.generateContent(prompt);
    const answer = result.response.text();

    // 5. Aggiorna il contatore con il nuovo FieldValue importato direttamente
    await userRef.set(
        { richiesteAiUsate: FieldValue.increment(1) },
        { merge: true },
    );

    return { answer };
  } catch (error) {
    console.error("ERRORE GLOBALE NELLA FUNCTION:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});