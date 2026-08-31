const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const {GoogleAuth} = require("google-auth-library");

initializeApp();
const db = getFirestore();

// La chiave viene letta SOLO da functions/.env
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.chatWithAssistant = onCall({timeoutSeconds: 120}, async (request) => {
  try {
    // 1. Verifica autenticazione
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // 2. Verifica accesso Premium/Trial lato server
    const isPremium = userData.isPremium === true;
    const trialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;
    const isTrialActive = trialEnd && trialEnd > new Date();

    if (!isPremium && !isTrialActive) {
      throw new HttpsError(
          "permission-denied",
          "Funzione riservata agli utenti Premium.",
      );
    }

    // 3. Verifica limite trial lato server
    const richiesteUsate = userData.richiesteAiUsate || 0;
    if (!isPremium && richiesteUsate >= 50) {
      throw new HttpsError(
          "resource-exhausted",
          "Hai raggiunto il limite di richieste AI del trial.",
      );
    }

    // 4. Costruisci il contesto e chiama Gemini
    const question = request.data.question;
    const summary = request.data.spendingSummary || "";

    const model = genAI.getGenerativeModel({model: "gemini-3.5-flash-lite"});
    const prompt = `Sei un assistente di budget familiare.
Rispondi in italiano, in modo breve e concreto.
Dati di riepilogo dell'utente: ${summary}
Domanda: ${question}`;

    const result = await model.generateContent(prompt);
    const answer = result.response.text();

    // 5. Aggiorna il contatore SOLO dopo una risposta riuscita
    await userRef.set(
        {richiesteAiUsate: FieldValue.increment(1)},
        {merge: true},
    );

    return {answer};
  } catch (error) {
    console.error("ERRORE GLOBALE NELLA FUNCTION:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- FASE 2/5: CLOUD FUNCTION PER SCANSIONE SCONTRINO E/O PRODOTTI ---

exports.scanReceipt = onCall({timeoutSeconds: 120}, async (request) => {
  try {
    // 1. Verifica autenticazione
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }

    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // 2. Verifica Premium / Trial
    const isPremium = userData.isPremium === true;
    const trialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;
    const isTrialActive = trialEnd && trialEnd > new Date();

    if (!isPremium && !isTrialActive) {
      throw new HttpsError(
          "permission-denied",
          "Funzione riservata agli utenti Premium.",
      );
    }

    // 3. Verifica limite scontrini trial
    const scontriniUsati = userData.scontriniUsati || 0;
    if (!isPremium && scontriniUsati >= 30) {
      throw new HttpsError(
          "resource-exhausted",
          "Hai raggiunto il limite di scansione scontrini del trial.",
      );
    }

    // 4. Ricevi le immagini in base64: scontrino e/o foto prodotti.
    // "imageBase64" resta supportato per compatibilità con lo scanner
    // solo-scontrino già in produzione (scan_receipt_screen.dart).
    const {imageBase64, receiptImageBase64, productsImageBase64} =
      request.data;
    const receiptImage = receiptImageBase64 || imageBase64 || null;
    const productsImage = productsImageBase64 || null;

    if (!receiptImage && !productsImage) {
      throw new HttpsError(
          "invalid-argument",
          "Fornisci almeno una foto: scontrino o prodotti.",
      );
    }

    // Nomi delle buste dell'utente, per far scegliere all'IA quella più
    // adatta ad ogni prodotto (evita di dover impostare la busta a mano).
    const envelopeNames = Array.isArray(request.data.envelopeNames) ?
      request.data.envelopeNames.filter((n) => typeof n === "string" && n) :
      [];
    // "NESSUNA" è la sentinella per "nessuna busta adatta": un enum Gemini
    // non accetta stringhe vuote come valore, quindi non possiamo usare "".
    const bustaEnum = envelopeNames.length > 0 ?
      [...envelopeNames, "NESSUNA"] : ["NESSUNA"];
    const busteText = envelopeNames.length > 0 ?
      `Buste disponibili dell'utente: ${
        envelopeNames.map((n) => `"${n}"`).join(", ")
      }.\n` +
      `Per ogni prodotto imposta "busta" con il nome ESATTO (copiato ` +
      `carattere per carattere da quelli elencati sopra) della busta più ` +
      `adatta a contenere quella spesa. Se nessuna busta elencata è ` +
      `chiaramente adatta, imposta "busta": "NESSUNA".\n` :
      `L'utente non ha ancora creato nessuna busta: imposta sempre ` +
      `"busta": "NESSUNA".\n`;

    const model = genAI.getGenerativeModel({
      model: "gemini-3.5-flash-lite",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            prodotti: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  nome: {type: "string"},
                  prezzo: {type: "number", nullable: true},
                  quantita: {type: "number"},
                  categoria: {type: "string"},
                  busta: {type: "string", enum: bustaEnum},
                  abbinato: {type: "boolean"},
                },
                required: [
                  "nome", "prezzo", "quantita", "categoria", "busta",
                  "abbinato",
                ],
              },
            },
          },
          required: ["prodotti"],
        },
      },
    });

    const parts = [];
    let prompt;

    if (receiptImage && productsImage) {
      prompt = `Ti fornisco due immagini: la PRIMA è lo scontrino di un ` +
        `acquisto, la SECONDA è una foto dei prodotti fisici acquistati.\n` +
        `Per ogni prodotto visibile nella seconda immagine, individua il ` +
        `nome e cerca di abbinarlo alla riga corrispondente sullo ` +
        `scontrino per recuperarne il prezzo esatto. Se non trovi una ` +
        `corrispondenza certa sullo scontrino, imposta "prezzo": null e ` +
        `"abbinato": false.\n` +
        busteText +
        `Restituisci unicamente un oggetto JSON con la struttura:\n` +
        `{"prodotti": [{"nome": "...", "prezzo": 12.50, "quantita": 1, ` +
        `"categoria": "Spesa", "busta": "...", "abbinato": true}]}\n` +
        `Campi: "nome" (string), "prezzo" (number o null se non ` +
        `abbinato), "quantita" (number, conta le unità visibili nella ` +
        `foto prodotti, default 1), "categoria" (string, una tra: Spesa, ` +
        `Casa, Trasporti, Salute, Svago, Altro), "busta" (string, vedi ` +
        `istruzioni sopra), "abbinato" (boolean, true solo se il prezzo ` +
        `proviene da una riga trovata sullo scontrino). Non omettere mai ` +
        `nessun campo.`;
      parts.push(
          {inlineData: {data: receiptImage, mimeType: "image/jpeg"}},
          {inlineData: {data: productsImage, mimeType: "image/jpeg"}},
      );
    } else if (receiptImage) {
      prompt = `Analizza l'immagine di questo scontrino ed estrai la ` +
        `lista dei prodotti acquistati.\n` +
        busteText +
        `Restituisci unicamente un oggetto JSON con la struttura:\n` +
        `{"prodotti": [{"nome": "...", "prezzo": 12.50, "quantita": 1, ` +
        `"categoria": "Spesa", "busta": "...", "abbinato": true}]}\n` +
        `Campi: "nome" (string), "prezzo" (number, usa il punto come ` +
        `separatore decimale), "quantita" (number, sempre 1 se lo ` +
        `scontrino non riporta una quantità esplicita), "categoria" ` +
        `(string, una tra: Spesa, Casa, Trasporti, Salute, Svago, Altro), ` +
        `"busta" (string, vedi istruzioni sopra), "abbinato" (boolean, ` +
        `imposta sempre true). Se un valore non è leggibile, usa "" per ` +
        `le stringhe e 0 per il prezzo, ma non omettere mai il campo.`;
      parts.push({inlineData: {data: receiptImage, mimeType: "image/jpeg"}});
    } else {
      prompt = `Analizza questa foto di un gruppo di prodotti fisici e ` +
        `identifica ciascun prodotto visibile. Non hai a disposizione lo ` +
        `scontrino, quindi non puoi conoscere il prezzo.\n` +
        busteText +
        `Restituisci unicamente un oggetto JSON con la struttura:\n` +
        `{"prodotti": [{"nome": "...", "prezzo": null, "quantita": 1, ` +
        `"categoria": "Spesa", "busta": "...", "abbinato": false}]}\n` +
        `Campi: "nome" (string), "prezzo" sempre null, "quantita" ` +
        `(number, conta le unità visibili dello stesso prodotto), ` +
        `"categoria" (string, una tra: Spesa, Casa, Trasporti, Salute, ` +
        `Svago, Altro), "busta" (string, vedi istruzioni sopra), ` +
        `"abbinato" sempre false. Non omettere mai nessun campo.`;
      parts.push({inlineData: {data: productsImage, mimeType: "image/jpeg"}});
    }

    const result = await model.generateContent([prompt, ...parts]);
    const responseText = result.response.text();
    const parsedData = JSON.parse(responseText);

    // 5. Aggiorna contatore scontrini usati
    await userRef.set(
        {scontriniUsati: FieldValue.increment(1)},
        {merge: true},
    );

    return parsedData;
  } catch (error) {
    console.error("ERRORE SCAN RECEIPT:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- FASE 4: FUNZIONI PER GESTIONE INVITI FAMIGLIA ---

exports.inviteFamilyMember = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Devi essere autenticato.");
  }
  const {familyId, email} = request.data;
  const familyRef = db.collection("families").doc(familyId);
  const familyDoc = await familyRef.get();

  if (!familyDoc.exists) {
    throw new HttpsError("not-found", "Famiglia non trovata.");
  }
  if (familyDoc.data().ownerId !== request.auth.uid) {
    throw new HttpsError(
        "permission-denied",
        "Solo il proprietario può invitare.",
    );
  }

  // Verifica che l'email corrisponda a un utente registrato
  try {
    await getAuth().getUserByEmail(email);
  } catch (e) {
    throw new HttpsError(
        "not-found",
        "Nessun utente registrato con questa email.",
    );
  }

  await familyRef.collection("invites").add({
    email: email,
    invitedBy: request.auth.uid,
    status: "pending",
    createdAt: new Date().toISOString(),
  });

  return {message: "Invito inviato."};
});

exports.acceptFamilyInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Devi essere autenticato.");
  }
  const {familyId, inviteId} = request.data;
  const userEmail = request.auth.token.email;

  const inviteRef = db
      .collection("families")
      .doc(familyId)
      .collection("invites")
      .doc(inviteId);
  const inviteDoc = await inviteRef.get();

  if (!inviteDoc.exists || inviteDoc.data().email !== userEmail) {
    throw new HttpsError(
        "permission-denied",
        "Invito non valido per questo utente.",
    );
  }

  const userRecord = await getAuth().getUser(request.auth.uid);

  await db
      .collection("families")
      .doc(familyId)
      .collection("members")
      .doc(request.auth.uid)
      .set({
        name: userRecord.displayName || userEmail,
        role: "member",
        colorTag: "#2563EB",
        joinedAt: new Date().toISOString(),
      });

  await db.collection("users").doc(request.auth.uid).set(
      {familyId: familyId},
      {merge: true},
  );

  await inviteRef.update({status: "accepted"});

  return {message: "Ti sei unito alla famiglia."};
});

// --- FASE 6: VERIFICA SERVER-SIDE ABBONAMENTO GOOGLE PLAY ---
//
// Non fidarsi MAI del client per lo stato Premium: questa funzione chiama
// la Google Play Developer API con le credenziali di un service account e
// scrive isPremium solo in base a quello che risponde Google, mai in base
// a quanto dichiara l'app. Finché GOOGLE_PLAY_SERVICE_ACCOUNT_JSON e
// ANDROID_PACKAGE_NAME non sono impostati in functions/.env, la funzione
// rifiuta esplicitamente la richiesta invece di far finta che l'acquisto
// sia valido.

let playAuthClient = null;

/**
 * Restituisce un client autenticato per la Play Developer API, oppure
 * null se le credenziali non sono ancora state configurate.
 * @return {GoogleAuth|null} il client di autenticazione o null.
 */
function getPlayAuthClient() {
  if (playAuthClient) return playAuthClient;
  const keyJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!keyJson) return null;
  let credentials;
  try {
    credentials = JSON.parse(keyJson);
  } catch (e) {
    console.error("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON non è un JSON valido.");
    return null;
  }
  playAuthClient = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  return playAuthClient;
}

const ACTIVE_SUBSCRIPTION_STATES = [
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
];

exports.verifyPlayPurchase = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }

    const {purchaseToken, productId} = request.data;
    if (typeof purchaseToken !== "string" || !purchaseToken ||
        typeof productId !== "string" || !productId) {
      throw new HttpsError(
          "invalid-argument",
          "purchaseToken e productId sono obbligatori.",
      );
    }

    const packageName = process.env.ANDROID_PACKAGE_NAME;
    const auth = getPlayAuthClient();
    if (!auth || !packageName) {
      throw new HttpsError(
          "failed-precondition",
          "Google Play Billing non è ancora configurato lato server: " +
          "imposta GOOGLE_PLAY_SERVICE_ACCOUNT_JSON e " +
          "ANDROID_PACKAGE_NAME in functions/.env (vedi CLAUDE.md).",
      );
    }

    const client = await auth.getClient();
    const url = "https://androidpublisher.googleapis.com/androidpublisher" +
      `/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/` +
      encodeURIComponent(purchaseToken);
    const response = await client.request({url});
    const subscription = response.data;

    const isActive = ACTIVE_SUBSCRIPTION_STATES.includes(
        subscription.subscriptionState,
    );
    const lineItem = (subscription.lineItems || []).find(
        (li) => li.productId === productId,
    );
    const expiryTime = lineItem ? lineItem.expiryTime : null;

    await db.collection("users").doc(request.auth.uid).set(
        {
          isPremium: isActive,
          playProductId: productId,
          playPurchaseToken: purchaseToken,
          playSubscriptionExpiry: expiryTime,
        },
        {merge: true},
    );

    return {isPremium: isActive, expiryTime};
  } catch (error) {
    console.error("ERRORE VERIFY PLAY PURCHASE:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});
