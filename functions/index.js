const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {getMessaging} = require("firebase-admin/messaging");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const {GoogleAuth} = require("google-auth-library");

initializeApp();
const db = getFirestore();

// La chiave viene letta SOLO da functions/.env
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

/**
 * Registra nei log i token realmente usati da una chiamata Gemini — mai
 * letti né loggati finora, quindi ogni stima di costo per chiamata era
 * basata solo sulla lettura dei prompt nel codice, non su dati reali.
 * Non altera in alcun modo il comportamento della funzione chiamante: un
 * solo console.log, nessuna chiamata aggiuntiva, nessun costo. Consultabile
 * con `firebase functions:log` o dalla Cloud Logging Console, filtrando su
 * "[gemini-tokens]".
 * @param {string} label Nome della funzione/kind che ha fatto la chiamata
 *   (es. "chatWithAssistant", "generateAiInsight:daily_tip").
 * @param {object} result Il valore restituito da model.generateContent().
 */
function logTokenUsage(label, result) {
  const usage = result.response.usageMetadata;
  if (!usage) return;
  console.log(
      `[gemini-tokens] ${label}: input=${usage.promptTokenCount} ` +
      `output=${usage.candidatesTokenCount} ` +
      `totale=${usage.totalTokenCount}`,
  );
}

// --- HELPER CONDIVISI: ACCESSO PREMIUM/TRIAL E QUOTA "ANALISI AVANZATE" ---
//
// Estratti da chatWithAssistant e scanReceipt (che li duplicavano) e usati
// anche da tutte le nuove funzioni dell'AI Premium proattiva (Blocchi 3-9
// del piano "consulente AI"), così il controllo di accesso resta un unico
// punto invece di essere ricopiato in ognuna.

/**
 * Verifica che l'utente abbia accesso Premium o Trial attivo, altrimenti
 * lancia HttpsError. Non fa alcuna verifica di limiti/contatori.
 * @param {object} userData Dati del documento users/{uid}.
 * @return {{isPremium: boolean, isTrialActive: boolean}} stato accesso.
 */
function requireActiveAccess(userData) {
  const isPremium = userData.isPremium === true;
  const trialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;
  const isTrialActive = Boolean(trialEnd && trialEnd > new Date());

  if (!isPremium && !isTrialActive) {
    throw new HttpsError(
        "permission-denied",
        "Funzione riservata agli utenti Premium.",
    );
  }
  return {isPremium, isTrialActive};
}

// --- MODELLO A DUE ABBONAMENTI (Premium base vs Premium Famiglia) ---
//
// Deciso con l'utente: la Famiglia non è più inclusa in qualunque Premium
// (come nel Blocco C originale) — diventa un abbonamento separato, più
// caro, che include tutto il Premium base più la possibilità di creare una
// famiglia con membri Free agganciati. Solo lo SCHEMA è pronto ora
// (campo `subscriptionTier` su users/{uid}, gestibile solo dalla function
// amministrativa): nessun prodotto Play Billing reale esiste ancora
// (bloccato sugli stessi prerequisiti di Fase 6a), quindi nessun vero
// pagamento è coinvolto in questo cambiamento. Il Trial continua a dare
// accesso di anteprima completo, Famiglia inclusa, senza bisogno del tier.

/**
 * Verifica che l'utente possa creare/mantenere una famiglia: Trial attivo
 * (anteprima completa), oppure Premium con subscriptionTier == "famiglia".
 * Un Premium senza questo tier viene respinto anche se ha accesso valido
 * alle altre funzioni Premium (AI, scanner, ecc.).
 * @param {object} userData Dati del documento users/{uid}.
 * @return {{isPremium: boolean, isTrialActive: boolean}} stato accesso.
 */
function requireFamilyTierAccess(userData) {
  const {isPremium, isTrialActive} = requireActiveAccess(userData);
  const hasFamilyTier = isPremium && userData.subscriptionTier === "famiglia";
  if (!hasFamilyTier && !isTrialActive) {
    throw new HttpsError(
        "permission-denied",
        "La Famiglia richiede il piano Premium Famiglia (non incluso nel " +
        "Premium base) oppure un Trial attivo.",
    );
  }
  return {isPremium, isTrialActive};
}

// Stesso limite di AppUser.trialMaxAnalisi in lib/models/app_user.dart:
// va tenuto allineato manualmente, come già per gli altri due contatori.
const TRIAL_MAX_ANALISI_AVANZATE = 10;

/**
 * Verifica che l'utente non abbia esaurito la quota trial di "analisi
 * avanzate" (contatore condiviso da tutte le funzioni AI Premium proattive:
 * distribuzione entrate, consiglio del giorno, report mensile, analisi
 * abitudini, insight famiglia, lista spesa assistita). Non incrementa nulla:
 * l'incremento va fatto con incrementAnalisiQuota SOLO dopo una risposta
 * riuscita di Gemini, mai prima.
 * @param {object} userData Dati del documento users/{uid}.
 * @param {boolean} isPremium Se true, nessun limite si applica.
 */
function requireAnalisiQuotaAvailable(userData, isPremium) {
  const analisiUsate = userData.analisiAvanzateUsate || 0;
  if (!isPremium && analisiUsate >= TRIAL_MAX_ANALISI_AVANZATE) {
    throw new HttpsError(
        "resource-exhausted",
        "Hai raggiunto il limite di analisi AI del trial.",
    );
  }
}

/**
 * Incrementa il contatore condiviso analisiAvanzateUsate. Va chiamata solo
 * dopo che la generazione AI è andata a buon fine.
 * @param {FirebaseFirestore.DocumentReference} userRef Riferimento a
 *   users/{uid}.
 */
async function incrementAnalisiQuota(userRef) {
  await userRef.set(
      {analisiAvanzateUsate: FieldValue.increment(1)},
      {merge: true},
  );
}

// --- BLOCCO D (cambio modello di business Famiglia): BLOCCO NON
// DISTRUTTIVO SU PREMIUM SCADUTO ---
//
// Un membro non-owner non può leggere users/{uid} dell'owner (le
// Firestore Rules lo permettono solo a se stessi), quindi né la UI né le
// Rules delle sottocollection famiglia (envelopes/expenses/incomes)
// possono verificare direttamente lo stato Premium dell'owner. Soluzione:
// denormalizzare ownerIsPremium/ownerTrialEnd su families/{familyId}
// stesso, riletti da qui ogni volta che lo stato Premium/Trial di un
// owner cambia. A differenza di users/{uid}.trialEnd (stringa ISO8601,
// per compatibilità con codice esistente), qui ownerTrialEnd è un vero
// Firestore Timestamp fin dall'inizio — permette un confronto diretto con
// request.time nelle Rules, cosa che una stringa non avrebbe permesso.

/**
 * Aggiorna ownerIsPremium/ownerTrialEnd su tutte le famiglie di cui uid è
 * owner, rileggendo lo stato fresco da users/{uid} (mai i valori passati
 * dal chiamante) per non rischiare disallineamenti se in futuro un'altra
 * funzione scrivesse solo isPremium o solo trialEnd senza l'altro.
 * @param {string} uid Uid dell'utente il cui stato Premium/Trial è appena
 *   cambiato.
 */
async function syncFamilyAccessForOwner(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data() || {};
  const ownerIsPremium = userData.isPremium === true;
  const ownerTrialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;

  const familiesSnap = await db.collection("families")
      .where("ownerId", "==", uid).get();
  if (familiesSnap.empty) return;

  const batch = db.batch();
  familiesSnap.forEach((doc) => {
    batch.update(doc.ref, {ownerIsPremium, ownerTrialEnd});
  });
  await batch.commit();
}

/**
 * Stessa logica di requireActiveAccess, ma sui campi denormalizzati di un
 * documento families/{familyId} invece che su users/{uid} — usata dove
 * serve verificare l'accesso dell'owner senza poter leggere il suo
 * documento utente privato (es. inviteFamilyMember, chiamata da chiunque
 * sia già owner ma che qui verifica lo stato salvato, non il proprio).
 * @param {object} familyData Dati del documento families/{familyId}.
 * @return {boolean} true se l'owner ha Premium o Trial attivo.
 */
function isFamilyAccessActive(familyData) {
  const ownerIsPremium = familyData.ownerIsPremium === true;
  const trialEnd = familyData.ownerTrialEnd ?
    familyData.ownerTrialEnd.toDate() : null;
  return ownerIsPremium || Boolean(trialEnd && trialEnd > new Date());
}

// --- RATE LIMITING: contatore a finestra fissa su Firestore ---
//
// Indipendente dai contatori Premium/Trial sopra (che limitano il consumo
// nel tempo, non la velocità): impedisce un numero eccessivo di chiamate
// nello stesso breve periodo, per uid e/o per IP. Un documento per chiave
// in rateLimits/{key}, mai letto/scritto dal client (bypassa le Firestore
// Rules perché scritto solo con l'Admin SDK).

/** Limiti per funzione: {maxCalls} chiamate ogni {windowMs} millisecondi. */
const RATE_LIMITS = {
  chatWithAssistant: {maxCalls: 5, windowMs: 60 * 1000},
  scanReceipt: {maxCalls: 3, windowMs: 60 * 1000},
  generateAiInsight: {maxCalls: 5, windowMs: 60 * 1000},
  suggestIncomeDistribution: {maxCalls: 5, windowMs: 60 * 1000},
  suggestShoppingList: {maxCalls: 5, windowMs: 60 * 1000},
  // startTrial ha un limite più stretto perché un abuso realistico è la
  // creazione rapida di molti account nuovi (uid sempre diversi): il
  // limite per uid da solo non basterebbe, va combinato con quello per IP
  // (vedi enforceStartTrialRateLimit più sotto).
  startTrialByUid: {maxCalls: 3, windowMs: 60 * 60 * 1000},
  startTrialByIp: {maxCalls: 5, windowMs: 60 * 60 * 1000},
};

/**
 * Verifica e aggiorna un contatore a finestra fissa per la chiave data.
 * Lancia HttpsError "resource-exhausted" se il limite è già stato
 * raggiunto nella finestra corrente. Finestra fissa (non scorrevole): un
 * piccolo "burst" al confine tra due finestre è possibile, accettato come
 * compromesso per la semplicità di un contatore atomico su Firestore.
 * @param {string} key Chiave univoca del contatore, es. "uid_scanReceipt".
 * @param {{maxCalls: number, windowMs: number}} limit Limite da applicare.
 */
async function enforceRateLimit(key, limit) {
  const ref = db.collection("rateLimits").doc(key);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const data = doc.exists ? doc.data() : null;
    if (!data || now - data.windowStart >= limit.windowMs) {
      tx.set(ref, {windowStart: now, count: 1});
      return;
    }
    if (data.count >= limit.maxCalls) {
      throw new HttpsError(
          "resource-exhausted",
          "Troppe richieste in poco tempo. Riprova tra qualche minuto.",
      );
    }
    tx.update(ref, {count: FieldValue.increment(1)});
  });
}

/**
 * Rate limit combinato per startTrial: per uid (copre i retry legittimi
 * dello stesso utente) e per IP (l'unica difesa efficace contro molti
 * account nuovi creati rapidamente, dato che ognuno ha un uid diverso).
 * @param {string} uid Uid dell'utente autenticato che chiama startTrial.
 * @param {string} ip IP del chiamante (request.rawRequest.ip).
 */
async function enforceStartTrialRateLimit(uid, ip) {
  await enforceRateLimit(`uid_${uid}_startTrial`, RATE_LIMITS.startTrialByUid);
  if (ip) {
    await enforceRateLimit(
        `ip_${ip}_startTrial`,
        RATE_LIMITS.startTrialByIp,
    );
  }
}

exports.chatWithAssistant = onCall({timeoutSeconds: 120}, async (request) => {
  try {
    // 1. Verifica autenticazione
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    await enforceRateLimit(
        `uid_${userId}_chatWithAssistant`,
        RATE_LIMITS.chatWithAssistant,
    );
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // 2. Verifica accesso Premium/Trial lato server
    const {isPremium} = requireActiveAccess(userData);

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
    const prompt = `Sei un assistente di budget familiare della app ` +
      `"Spesa Intelligente". Rispondi sempre in italiano, in modo breve ` +
      `e concreto.

REGOLA FONDAMENTALE: non hai alcuna capacità di creare, modificare o ` +
      `eliminare buste, spese, entrate, obiettivi o qualsiasi altro dato ` +
      `dell'utente. Puoi SOLO leggere il riepilogo fornito qui sotto e ` +
      `dare consigli o informazioni basati su di esso.
Se l'utente ti chiede di eseguire un'azione (es. "crea una busta", ` +
      `"registra una spesa", "sposta dei soldi", "cancella l'obiettivo"), ` +
      `NON fingere MAI di averla eseguita: non inventare conferme, saldi ` +
      `aggiornati o nuovi dati che non provengono dal riepilogo fornito. ` +
      `Spiega chiaramente che non puoi farlo direttamente da qui e indica ` +
      `in modo specifico dove/come può farlo da solo nell'app (es. ` +
      `"Puoi creare una nuova busta dalla schermata Buste con il ` +
      `pulsante +", "Puoi registrare questa spesa dalla schermata Spese ` +
      `o scansionando lo scontrino").

Dati di riepilogo dell'utente: ${summary}
Domanda: ${question}`;

    const result = await model.generateContent(prompt);
    logTokenUsage("chatWithAssistant", result);
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
    await enforceRateLimit(
        `uid_${userId}_scanReceipt`,
        RATE_LIMITS.scanReceipt,
    );
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // 2. Verifica Premium / Trial
    const {isPremium} = requireActiveAccess(userData);

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
    logTokenUsage("scanReceipt", result);
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

// --- AI PREMIUM PROATTIVA: FUNZIONE CONDIVISA PER GLI INSIGHT NARRATIVI ---
//
// Un'unica Cloud Function per tutti gli insight testuali generati da
// Gemini (mai per calcoli/somme, solo per la frase finale), selezionati
// con "kind". Kind cablati finora:
//   - "daily_tip" / "monthly_report" (Blocco 4): la function aggrega i
//     dati lato server (Admin SDK), scrive il risultato in cache su
//     users/{uid} (aiDailyTip / aiMonthlyReport) e, se la cache per il
//     giorno/mese corrente è già valida, la restituisce senza richiamare
//     Gemini né consumare quota — rigenerazione al massimo una volta al
//     giorno/mese, come da piano.
//   - "habit_analysis" (Blocco 5): riceve un summary già compatto (medie
//     mensili per categoria, variazioni recenti) costruito lato client
//     con HabitInsights.buildSummary, come chatWithAssistant. On-demand,
//     nessuna cache.
//   - "family_analysis" (Blocco 8): riceve un summary compatto costruito
//     lato client con FamilyInsights.buildSummary. On-demand, nessuna
//     cache; mai giudizi sulle persone.

/**
 * Aggrega, solo con letture Firestore (Admin SDK, nessuna chiamata AI), un
 * riepilogo compatto delle finanze PERSONALI del mese corrente dell'utente:
 * spese per categoria, entrate/spese totali, quota mensile degli obiettivi
 * di risparmio attivi. Stessa struttura/regole del riepilogo già costruito
 * lato client in ai_chat_screen.dart — mai dati familiari, mai transazioni
 * singole.
 * @param {string} userId L'uid dell'utente (sempre quello della richiesta,
 *   mai di un altro utente).
 * @return {Promise<{summary: string, totalEntrate: number,
 *   totalSpeso: number}>} riepilogo testuale e totali del mese.
 */
async function buildPersonalMonthlySummary(userId) {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startOfNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const startIso = startOfMonth.toISOString();
  const endIso = startOfNextMonth.toISOString();

  const userExpenses = db.collection("users").doc(userId).collection(
      "expenses",
  );
  const userIncomes = db.collection("users").doc(userId).collection(
      "incomes",
  );
  const userChallenges = db.collection("users").doc(userId).collection(
      "challenges",
  );

  const [expensesSnap, incomesSnap, challengesSnap] = await Promise.all([
    userExpenses.where("date", ">=", startIso).where("date", "<", endIso)
        .get(),
    userIncomes.where("date", ">=", startIso).where("date", "<", endIso)
        .get(),
    userChallenges.get(),
  ]);

  const byCategory = {};
  let totalSpeso = 0;
  expensesSnap.forEach((doc) => {
    const d = doc.data();
    const amount = Number(d.amount) || 0;
    const category = d.category || "Altro";
    byCategory[category] = (byCategory[category] || 0) + amount;
    totalSpeso += amount;
  });

  let totalEntrate = 0;
  incomesSnap.forEach((doc) => {
    totalEntrate += Number(doc.data().amount) || 0;
  });

  const goalLines = [];
  challengesSnap.forEach((doc) => {
    const c = doc.data();
    if (c.type !== "saving" || !c.deadline) return;
    const target = Number(c.targetAmount) || 0;
    const saved = Number(c.savedAmount) || 0;
    if (target <= 0 || saved >= target) return;
    const deadline = c.deadline.toDate ?
      c.deadline.toDate() : new Date(c.deadline);
    const monthsLeft = (deadline.getFullYear() - now.getFullYear()) * 12 +
      (deadline.getMonth() - now.getMonth());
    if (monthsLeft <= 0) return;
    const quota = (target - saved) / monthsLeft;
    goalLines.push(
        `"${c.title}" quota mensile consigliata €${quota.toFixed(2)}`,
    );
  });

  const categorie = Object.entries(byCategory)
      .map(([nome, importo]) => `${nome}: €${importo.toFixed(0)}`)
      .join(", ");

  let summary = categorie ?
    `Spese per categoria questo mese: ${categorie}.\n` :
    "Nessuna spesa registrata questo mese.\n";
  summary += `Entrate: €${totalEntrate.toFixed(2)}   |   ` +
    `Spese: €${totalSpeso.toFixed(2)}\n`;
  if (goalLines.length > 0) {
    summary += `Obiettivi di risparmio attivi: ${goalLines.join(", ")}.\n`;
  }

  return {summary, totalEntrate, totalSpeso};
}

/**
 * Consiglio del giorno: cache-o-genera, stessa logica già in uso dal ramo
 * "daily_tip" di generateAiInsight — estratta qui per essere riusata anche
 * dalla notifica push proattiva Premium (dailyScheduledChecks), che non ha
 * un request.auth su cui appoggiarsi (gira per tutti gli utenti via Admin
 * SDK), quindi non può chiamare la Cloud Function callable direttamente.
 * @param {string} userId Uid dell'utente.
 * @param {FirebaseFirestore.DocumentReference} userRef Riferimento a
 *   users/{uid}.
 * @param {object} userData Dati correnti del documento utente.
 * @param {boolean} isPremium Se true, nessun limite di quota si applica.
 * @return {Promise<{text: string, cached: boolean}>} il consiglio del
 *   giorno.
 */
async function getOrGenerateDailyTip(userId, userRef, userData, isPremium) {
  const now = new Date();
  const todayKey = now.toISOString().slice(0, 10);
  const cached = userData.aiDailyTip;
  if (cached && cached.dateKey === todayKey) {
    return {text: cached.text, cached: true};
  }

  // Solo generare da zero consuma la quota condivisa.
  requireAnalisiQuotaAvailable(userData, isPremium);
  const {summary} = await buildPersonalMonthlySummary(userId);

  const model = genAI.getGenerativeModel({
    model: "gemini-3.5-flash-lite",
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "object",
        properties: {text: {type: "string"}},
        required: ["text"],
      },
    },
  });
  const prompt = "Sei un consulente di budget personale. Basandoti " +
    "SOLO sui dati reali forniti qui sotto (non inventare mai " +
    "numeri), scrivi un unico consiglio pratico e specifico per " +
    "oggi, in italiano, massimo due frasi, tono amichevole e " +
    `concreto.\n${summary}`;
  const result = await model.generateContent(prompt);
  logTokenUsage("generateAiInsight:daily_tip", result);
  const parsed = JSON.parse(result.response.text());
  const text = typeof parsed.text === "string" ? parsed.text : "";

  await userRef.set({
    aiDailyTip: {
      text, dateKey: todayKey, generatedAt: now.toISOString(),
    },
  }, {merge: true});
  await incrementAnalisiQuota(userRef);

  return {text, cached: false};
}

exports.generateAiInsight = onCall({timeoutSeconds: 120}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    await enforceRateLimit(
        `uid_${userId}_generateAiInsight`,
        RATE_LIMITS.generateAiInsight,
    );
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};
    const now = new Date();

    // Accesso Premium/Trial richiesto sempre, anche per servire dalla
    // cache: resta comunque una funzionalità Premium.
    const {isPremium} = requireActiveAccess(userData);

    const kind = request.data.kind;

    if (kind === "daily_tip") {
      const {text, cached} =
        await getOrGenerateDailyTip(userId, userRef, userData, isPremium);
      return {kind, text, cached};
    }

    if (kind === "monthly_report") {
      const monthKey = now.toISOString().slice(0, 7); // yyyy-MM
      const cached = userData.aiMonthlyReport;
      if (cached && cached.monthKey === monthKey) {
        return {kind, ...cached, cached: true};
      }

      requireAnalisiQuotaAvailable(userData, isPremium);
      const {summary, totalEntrate, totalSpeso} =
        await buildPersonalMonthlySummary(userId);

      const model = genAI.getGenerativeModel({
        model: "gemini-3.5-flash-lite",
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              puntoDiForza: {type: "string"},
              attenzione: {type: "string"},
              consiglio: {type: "string"},
            },
            required: ["puntoDiForza", "attenzione", "consiglio"],
          },
        },
      });
      const prompt = "Sei un consulente di budget personale. Basandoti " +
        "SOLO sui dati reali forniti qui sotto (non inventare mai " +
        "numeri), scrivi in italiano tre frasi brevi e distinte per un " +
        "report mensile: \"puntoDiForza\" (cosa sta andando bene), " +
        "\"attenzione\" (cosa richiede attenzione), \"consiglio\" " +
        "(un'azione concreta da fare questo mese). Una sola frase per " +
        `campo, tono amichevole, mai giudicante.\n${summary}`;
      const result = await model.generateContent(prompt);
      logTokenUsage("generateAiInsight:monthly_report", result);
      const parsed = JSON.parse(result.response.text());

      const report = {
        puntoDiForza: typeof parsed.puntoDiForza === "string" ?
          parsed.puntoDiForza : "",
        attenzione: typeof parsed.attenzione === "string" ?
          parsed.attenzione : "",
        consiglio: typeof parsed.consiglio === "string" ?
          parsed.consiglio : "",
        totalEntrate,
        totalSpeso,
        monthKey,
        generatedAt: now.toISOString(),
      };

      await userRef.set({aiMonthlyReport: report}, {merge: true});
      await incrementAnalisiQuota(userRef);

      return {kind, ...report, cached: false};
    }

    if (kind === "habit_analysis") {
      // Blocco 5 del piano (punti 3+5): a differenza di daily_tip/
      // monthly_report, qui il riepilogo (medie mensili per categoria,
      // variazioni recenti già calcolate in Dart) arriva dal client, come
      // per chatWithAssistant — non è un contenuto in cache, è on-demand.
      requireAnalisiQuotaAvailable(userData, isPremium);
      const summary = typeof request.data.summary === "string" ?
        request.data.summary : "";
      if (!summary) {
        throw new HttpsError(
            "invalid-argument",
            "Serve un riepilogo delle abitudini di spesa da analizzare.",
        );
      }

      const model = genAI.getGenerativeModel({
        model: "gemini-3.5-flash-lite",
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {text: {type: "string"}},
            required: ["text"],
          },
        },
      });
      const prompt = "Sei un consulente di budget personale. Basandoti " +
        "SOLO sui dati reali forniti qui sotto (medie mensili e " +
        "variazioni già calcolate, non inventare mai numeri), scrivi " +
        "un'analisi breve in italiano (massimo 3-4 frasi): evidenzia un " +
        "pattern o una variazione significativa nelle abitudini di " +
        "spesa, poi concludi con un consiglio pratico e specifico per " +
        `risparmiare. Tono amichevole, mai giudicante.\n${summary}`;
      const result = await model.generateContent(prompt);
      logTokenUsage("generateAiInsight:habit_analysis", result);
      const parsed = JSON.parse(result.response.text());
      const text = typeof parsed.text === "string" ? parsed.text : "";

      await incrementAnalisiQuota(userRef);

      return {kind, text};
    }

    if (kind === "family_analysis") {
      // Blocco 8 del piano (punto 9): come habit_analysis, riceve un
      // riepilogo già compatto costruito lato client con
      // FamilyInsights.buildSummary (solo numeri/percentuali già
      // calcolati). Il client legge i dati familiari solo tramite le
      // Firestore Rules esistenti (isMember()): questa function non legge
      // mai families/... per conto di un altro utente.
      requireAnalisiQuotaAvailable(userData, isPremium);
      const summary = typeof request.data.summary === "string" ?
        request.data.summary : "";
      if (!summary) {
        throw new HttpsError(
            "invalid-argument",
            "Serve un riepilogo delle spese familiari da analizzare.",
        );
      }

      const model = genAI.getGenerativeModel({
        model: "gemini-3.5-flash-lite",
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {text: {type: "string"}},
            required: ["text"],
          },
        },
      });
      const prompt = "Sei un consulente di budget familiare. Basandoti " +
        "SOLO sui dati reali forniti qui sotto (numeri e percentuali già " +
        "calcolati, non inventare mai nulla), scrivi un'analisi breve in " +
        "italiano (massimo 3 frasi) dell'andamento delle spese " +
        "familiari. Fornisci solo informazioni utili per il budget: non " +
        "esprimere MAI giudizi sulle persone o su chi spende di più, " +
        `resta neutro e concreto.\n${summary}`;
      const result = await model.generateContent(prompt);
      logTokenUsage("generateAiInsight:family_analysis", result);
      const parsed = JSON.parse(result.response.text());
      const text = typeof parsed.text === "string" ? parsed.text : "";

      await incrementAnalisiQuota(userRef);

      return {kind, text};
    }

    throw new HttpsError(
        "invalid-argument",
        `Tipo di insight non supportato: "${kind}".`,
    );
  } catch (error) {
    console.error("ERRORE GENERATE AI INSIGHT:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- AI PREMIUM PROATTIVA (Blocco 3 del piano): DISTRIBUZIONE ENTRATE ---
//
// Punti 2+6 del piano: suggerisce come distribuire una nuova entrata tra le
// buste esistenti. A differenza di generateAiInsight, qui serve un output
// STRUTTURATO (importo per busta) perché il client lo usa per precompilare
// il form di una nuova entrata — mai per applicarlo automaticamente, quello
// resta sempre un'azione esplicita dell'utente (bottone "Applica
// distribuzione" + comunque il salvataggio finale della entrata).

exports.suggestIncomeDistribution = onCall(
    {timeoutSeconds: 120},
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Devi essere autenticato.");
        }
        const userId = request.auth.uid;
        await enforceRateLimit(
            `uid_${userId}_suggestIncomeDistribution`,
            RATE_LIMITS.suggestIncomeDistribution,
        );
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        const userData = userDoc.data() || {};

        // 1. Accesso Premium/Trial e quota condivisa (stessa di
        // generateAiInsight), prima di validare qualunque altro parametro.
        const {isPremium} = requireActiveAccess(userData);
        requireAnalisiQuotaAvailable(userData, isPremium);

        // 2. Validazione input.
        const incomeAmount = Number(request.data.incomeAmount);
        const envelopes = Array.isArray(request.data.envelopes) ?
          request.data.envelopes.filter(
              (e) => e && typeof e.id === "string" && typeof e.name ===
              "string",
          ) :
          [];
        const summary = typeof request.data.summary === "string" ?
          request.data.summary : "";

        if (!Number.isFinite(incomeAmount) || incomeAmount <= 0) {
          throw new HttpsError(
              "invalid-argument",
              "incomeAmount deve essere un numero positivo.",
          );
        }
        if (envelopes.length === 0) {
          throw new HttpsError(
              "invalid-argument",
              "Serve almeno una busta per proporre una distribuzione.",
          );
        }

        const envelopeIds = envelopes.map((e) => e.id);

        const model = genAI.getGenerativeModel({
          model: "gemini-3.5-flash-lite",
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: {
                allocazioni: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      envelopeId: {type: "string", enum: envelopeIds},
                      importo: {type: "number"},
                    },
                    required: ["envelopeId", "importo"],
                  },
                },
                motivazione: {type: "string"},
              },
              required: ["allocazioni", "motivazione"],
            },
          },
        });

        const prompt = "Sei un consulente di budget familiare. L'utente " +
          `ha ricevuto un'entrata di €${incomeAmount.toFixed(2)} e vuole ` +
          "un consiglio su come distribuirla tra le sue buste, basandoti " +
          "SOLO sui dati reali forniti qui sotto (non inventare mai " +
          `numeri).\n${summary}\n` +
          "Proponi una distribuzione: la somma di tutti gli \"importo\" " +
          "deve avvicinarsi il più possibile a " +
          `€${incomeAmount.toFixed(2)} senza mai superarlo (va bene ` +
          "lasciare una parte non assegnata se ha senso). Non è " +
          "necessario dare qualcosa a ogni busta. Dai priorità alle buste " +
          "più vicine a esaurirsi e agli eventuali obiettivi di risparmio " +
          "con quota mensile indicata. Se lo storico fornito mostra " +
          "categorie di spesa in aumento o un'entrata insolita rispetto " +
          "al solito, tienine conto nella proposta. Aggiungi " +
          "\"motivazione\": una sola frase breve in italiano che spieghi " +
          "la logica principale della proposta.";

        const result = await model.generateContent(prompt);
        logTokenUsage("suggestIncomeDistribution", result);
        const parsed = JSON.parse(result.response.text());

        // 3. Normalizza lato server: il client userà questi numeri per
        // precompilare il form, quindi devono quadrare sempre (mai oltre
        // il totale dichiarato, mai importi negativi) anche se il modello
        // arrotonda o sbaglia leggermente la somma.
        const rawAllocazioni = Array.isArray(parsed.allocazioni) ?
          parsed.allocazioni : [];
        const cleaned = rawAllocazioni
            .filter(
                (a) => a && envelopeIds.includes(a.envelopeId) &&
                Number.isFinite(a.importo) && a.importo > 0,
            )
            .map((a) => ({envelopeId: a.envelopeId, importo: a.importo}));
        const sum = cleaned.reduce((s, a) => s + a.importo, 0);
        const scale = sum > incomeAmount && sum > 0 ? incomeAmount / sum : 1;
        const allocazioni = cleaned.map((a) => ({
          envelopeId: a.envelopeId,
          importo: Math.round(a.importo * scale * 100) / 100,
        }));

        // 4. Aggiorna il contatore condiviso SOLO dopo una risposta
        // riuscita.
        await incrementAnalisiQuota(userRef);

        return {
          allocazioni,
          motivazione: typeof parsed.motivazione === "string" ?
            parsed.motivazione : "",
        };
      } catch (error) {
        console.error("ERRORE SUGGEST INCOME DISTRIBUTION:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    },
);

// --- AI PREMIUM PROATTIVA (Blocco 9 del piano): LISTA SPESA CON BUDGET ---
//
// Punto 10a: "Devo fare la spesa con €80" -> l'AI propone una lista. Come
// suggestIncomeDistribution, serve output STRUTTURATO (elenco di articoli
// con prezzo stimato), non prosa, perché il client li aggiunge come voci
// alla lista della spesa solo dopo conferma esplicita — mai in automatico.

exports.suggestShoppingList = onCall(
    {timeoutSeconds: 120},
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Devi essere autenticato.");
        }
        const userId = request.auth.uid;
        await enforceRateLimit(
            `uid_${userId}_suggestShoppingList`,
            RATE_LIMITS.suggestShoppingList,
        );
        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        const userData = userDoc.data() || {};

        const {isPremium} = requireActiveAccess(userData);
        requireAnalisiQuotaAvailable(userData, isPremium);

        const budget = Number(request.data.budget);
        const summary = typeof request.data.summary === "string" ?
          request.data.summary : "";

        if (!Number.isFinite(budget) || budget <= 0) {
          throw new HttpsError(
              "invalid-argument",
              "budget deve essere un numero positivo.",
          );
        }

        const model = genAI.getGenerativeModel({
          model: "gemini-3.5-flash-lite",
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: {
              type: "object",
              properties: {
                articoli: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      nome: {type: "string"},
                      prezzoStimato: {type: "number"},
                    },
                    required: ["nome", "prezzoStimato"],
                  },
                },
                motivazione: {type: "string"},
              },
              required: ["articoli", "motivazione"],
            },
          },
        });

        const prompt = "Sei un assistente per la spesa. L'utente ha un " +
          `budget di €${budget.toFixed(2)}. Basandoti SOLO sui prodotti ` +
          "che compra abitualmente e sui loro prezzi medi storici " +
          "forniti qui sotto, proponi una lista della spesa che rispetti " +
          "il budget indicato. Per i prodotti elencati nello storico usa " +
          "ESATTAMENTE il prezzo medio fornito, senza mai modificarlo: " +
          "se non entra nel budget, escludi quel prodotto invece di " +
          "cambiarne il prezzo. Dai sempre priorità ai prodotti abituali " +
          "dell'utente; puoi aggiungere al massimo un paio di prodotti " +
          "base non presenti nello storico solo se necessario per una " +
          "spesa sensata, stimandone un prezzo plausibile. La somma di " +
          "tutti i \"prezzoStimato\" non deve superare il budget. " +
          "Aggiungi \"motivazione\": una sola frase breve in italiano " +
          `che spieghi la scelta.\n${summary}`;

        const result = await model.generateContent(prompt);
        logTokenUsage("suggestShoppingList", result);
        const parsed = JSON.parse(result.response.text());

        // Normalizza lato server: se il modello sfora comunque il budget,
        // togli articoli dalla fine finché il totale non rientra (non ha
        // senso "scalare" i prezzi di una lista della spesa come per un
        // importo di denaro).
        const rawArticoli = Array.isArray(parsed.articoli) ?
          parsed.articoli : [];
        const cleaned = rawArticoli.filter(
            (a) => a && typeof a.nome === "string" && a.nome &&
            Number.isFinite(a.prezzoStimato) && a.prezzoStimato > 0,
        );
        const articoli = [];
        let total = 0;
        for (const a of cleaned) {
          if (total + a.prezzoStimato > budget) continue;
          articoli.push({nome: a.nome, prezzoStimato: a.prezzoStimato});
          total += a.prezzoStimato;
        }

        await incrementAnalisiQuota(userRef);

        return {
          articoli,
          totaleStimato: Math.round(total * 100) / 100,
          motivazione: typeof parsed.motivazione === "string" ?
            parsed.motivazione : "",
        };
      } catch (error) {
        console.error("ERRORE SUGGEST SHOPPING LIST:", error);
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError("internal", error.message);
      }
    },
);

// --- BLOCCO C (cambio modello di business Famiglia): FAMIGLIA COME
// FUNZIONE PREMIUM ---
//
// Prima era una scrittura diretta dal client (family_service.dart), senza
// alcun controllo Premium né lato client né nelle Firestore Rules. Ora
// passa da questa Cloud Function, l'unico modo per creare una famiglia
// (firestore.rules blocca "allow create: if false" sul client). Trial
// conta come accesso valido, stessa equivalenza di requireActiveAccess
// già usata ovunque nel resto dell'app (confermato con l'utente).
exports.createFamily = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};
    requireFamilyTierAccess(userData);

    const name = String(request.data.name || "").trim();
    if (!name) {
      throw new HttpsError(
          "invalid-argument",
          "Il nome della famiglia è obbligatorio.",
      );
    }

    const userRecord = await getAuth().getUser(userId);
    const familyRef = db.collection("families").doc();
    await familyRef.set({
      name,
      ownerId: userId,
      createdAt: new Date().toISOString(),
      // Blocco D: denormalizzati subito alla creazione dallo stesso
      // userData già letto sopra per requireActiveAccess, invece di una
      // chiamata separata a syncFamilyAccessForOwner.
      ownerIsPremium: userData.isPremium === true,
      ownerTrialEnd: userData.trialEnd ? new Date(userData.trialEnd) : null,
    });
    await familyRef.collection("members").doc(userId).set({
      name: userRecord.displayName || "Io",
      role: "owner",
      colorTag: "#16B98C",
      joinedAt: new Date().toISOString(),
    });
    await userRef.set({familyId: familyRef.id}, {merge: true});

    return {familyId: familyRef.id};
  } catch (error) {
    console.error("ERRORE CREATE FAMILY:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- SPESE RICORRENTI COME FUNZIONE PREMIUM ---
//
// Trovato nell'audit del 2026-09-03: erano liberamente creabili da
// qualunque utente Free, sia lato client sia lato Firestore Rules —
// contraddice il requisito esplicito dell'utente ("le spese ricorrenti
// sono una funzionalità Premium"). Solo la CREAZIONE passa da qui: gestire
// (modificare/eliminare/confermare) una spesa ricorrente già esistente
// resta una scrittura diretta client (stesso pattern di
// buste/spese/entrate/challenge) — non è "usare" la funzionalità Premium,
// è amministrare un dato che l'utente ha già.
exports.addRecurringExpense = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    requireActiveAccess(userDoc.data() || {});

    const {description, amount, envelopeId, dayOfMonth} = request.data || {};
    if (typeof description !== "string" || !description.trim()) {
      throw new HttpsError(
          "invalid-argument", "La descrizione è obbligatoria.",
      );
    }
    const amountNum = Number(amount);
    if (!Number.isFinite(amountNum) || amountNum <= 0) {
      throw new HttpsError(
          "invalid-argument", "amount deve essere un numero positivo.",
      );
    }
    if (typeof envelopeId !== "string" || !envelopeId) {
      throw new HttpsError("invalid-argument", "envelopeId è obbligatorio.");
    }
    const dayNum = Number(dayOfMonth);
    if (!Number.isInteger(dayNum) || dayNum < 1 || dayNum > 28) {
      throw new HttpsError(
          "invalid-argument", "dayOfMonth deve essere tra 1 e 28.",
      );
    }

    const docRef = await userRef.collection("recurringExpenses").add({
      description: description.trim(),
      amount: amountNum,
      envelopeId,
      dayOfMonth: dayNum,
      active: true,
      lastGeneratedMonthKey: null,
    });

    return {id: docRef.id};
  } catch (error) {
    console.error("ERRORE ADD RECURRING EXPENSE:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// Membri totali per famiglia, owner incluso (X del piano concordato con
// l'utente: 3 totali = owner + 2 membri Free). Un solo posto Premium
// (l'owner) basta a sbloccare l'accesso per tutta la famiglia, quindi il
// limite serve a impedire che troppe persone si "agganciano" gratis a un
// unico abbonamento.
const MAX_FAMILY_MEMBERS = 3;

// --- FASE 4: FUNZIONI PER GESTIONE INVITI FAMIGLIA ---

exports.inviteFamilyMember = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Devi essere autenticato.");
  }
  const {familyId} = request.data;
  const email = (request.data.email || "").trim().toLowerCase();
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

  // Blocco D: non ha senso far entrare nuovi membri in una famiglia il cui
  // accesso è bloccato — gli inviti già pendenti restano comunque
  // accettabili (acceptFamilyInvite non ha questo controllo), solo la
  // creazione di NUOVI inviti è bloccata.
  if (!isFamilyAccessActive(familyDoc.data())) {
    throw new HttpsError(
        "failed-precondition",
        "Il Premium del proprietario è scaduto: riattivalo per invitare " +
        "nuovi membri.",
    );
  }

  // Controllo rapido lato invito (non l'unica difesa: il conteggio reale
  // e definitivo è nella transazione di acceptFamilyInvite più sotto, che
  // copre anche il caso di più inviti pendenti accettati in parallelo).
  const membersSnap = await familyRef.collection("members").get();
  if (membersSnap.size >= MAX_FAMILY_MEMBERS) {
    throw new HttpsError(
        "resource-exhausted",
        `La famiglia ha già raggiunto il numero massimo di ` +
        `${MAX_FAMILY_MEMBERS} membri.`,
    );
  }

  // Verifica che l'email corrisponda a un utente registrato
  let invitedUser;
  try {
    invitedUser = await getAuth().getUserByEmail(email);
  } catch (e) {
    throw new HttpsError(
        "not-found",
        "Nessun utente registrato con questa email.",
    );
  }

  await familyRef.collection("invites").add({
    email: email,
    // Chiave reale di corrispondenza per la query collectionGroup del
    // destinatario (vedi streamMyPendingInvites in family_service.dart e
    // il match top-level {path=**}/invites in firestore.rules): l'uid
    // resta la fonte di verità; `email` serve solo a mostrare il
    // destinatario nella UI dell'invito.
    invitedUid: invitedUser.uid,
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
  const userEmail = (request.auth.token.email || "").toLowerCase();

  const familyRef = db.collection("families").doc(familyId);
  const inviteRef = familyRef.collection("invites").doc(inviteId);
  const memberRef = familyRef.collection("members").doc(request.auth.uid);
  const userRef = db.collection("users").doc(request.auth.uid);

  const userRecord = await getAuth().getUser(request.auth.uid);

  // Transazione: sia la verifica dell'invito sia il conteggio membri
  // (Blocco C, limite MAX_FAMILY_MEMBERS) devono restare atomici insieme
  // alla scrittura del nuovo membro, altrimenti due inviti accettati nello
  // stesso istante potrebbero superare entrambi il limite prima che il
  // conteggio si aggiorni.
  await db.runTransaction(async (tx) => {
    const inviteDoc = await tx.get(inviteRef);
    // Admin SDK: bypassa le Firestore Rules, quindi qui il confronto
    // sull'uid è solo la verifica applicativa (stessa fonte di verità
    // della query collectionGroup del client) — nessun vincolo di
    // "provabilità" query qui.
    if (!inviteDoc.exists ||
        inviteDoc.data().invitedUid !== request.auth.uid) {
      throw new HttpsError(
          "permission-denied",
          "Invito non valido per questo utente.",
      );
    }

    const membersSnap = await tx.get(familyRef.collection("members"));
    if (membersSnap.size >= MAX_FAMILY_MEMBERS) {
      throw new HttpsError(
          "resource-exhausted",
          `La famiglia ha già raggiunto il numero massimo di ` +
          `${MAX_FAMILY_MEMBERS} membri.`,
      );
    }

    tx.set(memberRef, {
      name: userRecord.displayName || userEmail,
      role: "member",
      colorTag: "#2563EB",
      joinedAt: new Date().toISOString(),
    });
    tx.set(userRef, {familyId: familyId}, {merge: true});
    tx.update(inviteRef, {status: "accepted"});
  });

  return {message: "Ti sei unito alla famiglia."};
});

// Rimuove un membro dalla famiglia. Solo il proprietario può farlo, e non
// può rimuovere se stesso in questo modo (per lasciare/sciogliere la
// famiglia serve un flusso diverso, non richiesto ora). Usa l'Admin SDK
// per aggiornare anche users/{memberId}.familyId, campo che il membro
// rimosso non potrebbe più scrivere da solo una volta perso l'accesso.
exports.removeFamilyMember = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Devi essere autenticato.");
  }
  const {familyId, memberId} = request.data;
  if (typeof familyId !== "string" || typeof memberId !== "string") {
    throw new HttpsError(
        "invalid-argument",
        "familyId e memberId sono obbligatori.",
    );
  }

  const familyRef = db.collection("families").doc(familyId);
  const familyDoc = await familyRef.get();
  if (!familyDoc.exists) {
    throw new HttpsError("not-found", "Famiglia non trovata.");
  }
  if (familyDoc.data().ownerId !== request.auth.uid) {
    throw new HttpsError(
        "permission-denied",
        "Solo il proprietario può rimuovere un membro.",
    );
  }
  if (memberId === familyDoc.data().ownerId) {
    throw new HttpsError(
        "failed-precondition",
        "Il proprietario non può rimuovere se stesso.",
    );
  }

  const memberRef = familyRef.collection("members").doc(memberId);
  const memberDoc = await memberRef.get();
  if (!memberDoc.exists) {
    throw new HttpsError("not-found", "Membro non trovato.");
  }

  await memberRef.delete();
  await db.collection("users").doc(memberId).set(
      {familyId: FieldValue.delete()},
      {merge: true},
  );

  return {message: "Membro rimosso dalla famiglia."};
});

// --- ATTIVAZIONE TRIAL SIMULATA (percorso di sviluppo/test in parallelo
// all'acquisto reale via Google Play Billing) ---
//
// In precedenza il client scriveva isPremium/trialEnd/contatori
// direttamente su Firestore. Questi campi sono ora bloccati in scrittura
// dal client nelle Firestore Rules (solo Cloud Function/Admin SDK possono
// scriverli), per evitare che un utente si auto-assegni Premium o resetti
// i contatori d'uso modificando solo il client: il trial va quindi attivato
// da qui, stesso comportamento di prima (15 giorni, contatori azzerati).

// --- BLOCCO B (revisione controllo accessi Premium durante la beta):
// FLAG PER DISATTIVARE IL TRIAL SELF-SERVICE ---
//
// Durante la beta il trial si attiva SOLO manualmente (Blocco A,
// adminSetPremiumStatus): letto da un unico documento di configurazione
// invece che tramite un nuovo deploy, così si riattiva in futuro (quando
// il trial self-service tornerà pubblico) modificando solo un documento
// Firestore, senza toccare il codice. Nessuna Firestore Rule necessaria:
// letto solo dall'Admin SDK, mai dal client. Fail-closed di proposito: se
// il documento non esiste ancora (come subito dopo questo deploy) il
// trial risulta disattivato di default, non il contrario.
/**
 * Legge il flag di configurazione che abilita/disabilita l'attivazione
 * self-service del trial (startTrial). Fail-closed: se il documento di
 * configurazione non esiste ancora, il trial risulta disattivato.
 * @return {Promise<boolean>} true solo se il flag è esplicitamente true.
 */
async function isSelfServiceTrialEnabled() {
  const doc = await db.collection("config").doc("beta").get();
  return doc.exists && doc.data().selfServiceTrialEnabled === true;
}

exports.startTrial = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    if (!(await isSelfServiceTrialEnabled())) {
      throw new HttpsError(
          "failed-precondition",
          "L'attivazione del trial gratuito è temporaneamente disattivata " +
          "durante la beta. Contatta l'amministratore per attivare il tuo " +
          "accesso Premium.",
      );
    }
    await enforceStartTrialRateLimit(
        request.auth.uid,
        request.rawRequest && request.rawRequest.ip,
    );
    const trialEnd = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000);
    await db.collection("users").doc(request.auth.uid).set(
        {
          isPremium: false,
          trialEnd: trialEnd.toISOString(),
          scontriniUsati: 0,
          richiesteAiUsate: 0,
          analisiAvanzateUsate: 0,
        },
        {merge: true},
    );
    // Blocco D: se questo utente è owner di una famiglia, il nuovo trial
    // deve riflettersi subito sull'accesso familiare denormalizzato.
    await syncFamilyAccessForOwner(request.auth.uid);
    return {trialEnd: trialEnd.toISOString()};
  } catch (error) {
    console.error("ERRORE START TRIAL:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- BLOCCO A (revisione controllo accessi Premium durante la beta):
// ATTIVAZIONE MANUALE PREMIUM/TRIAL ---
//
// Sostituisce qualunque futuro meccanismo di auto-assegnazione: durante la
// beta, Premium/Trial si attivano SOLO chiamando questa funzione, e SOLO
// dall'account amministratore elencato qui sotto. Nessuna UI in-app la
// espone (nessuno schermo "riservato" esiste ancora, vedi Fase H nel
// piano) — va chiamata direttamente (Firebase Console → Functions → test,
// oppure un token ID reale + una richiesta HTTPS diretta), documentato in
// CLAUDE.md.
const ADMIN_EMAILS = ["alessandrocoo@hotmail.it"];

// Utility temporanea one-shot: verifica se in produzione esistono famiglie
// create PRIMA del Blocco C/D (quindi senza ownerIsPremium/ownerTrialEnd),
// che risulterebbero bloccate per errore dalle nuove Firestore Rules
// (fail-closed su campi mancanti) senza che l'owner abbia mai perso
// davvero l'accesso. Backfilla con lo stato reale attuale dell'owner
// (riusa syncFamilyAccessForOwner, la stessa funzione già in produzione) —
// non distruttivo, non inventa nulla: se l'owner non ha oggi Premium/Trial
// attivo la famiglia risulterà bloccata anche dopo, correttamente. Da
// rimuovere dopo l'uso, non è pensata per restare permanente.
exports.adminBackfillFamilyAccess = onCall(async (request) => {
  if (!request.auth || !ADMIN_EMAILS.includes(request.auth.token.email)) {
    throw new HttpsError(
        "permission-denied",
        "Funzione riservata all'amministratore.",
    );
  }
  const familiesSnap = await db.collection("families").get();
  const report = [];
  for (const doc of familiesSnap.docs) {
    const data = doc.data();
    const hadFields = Object.prototype.hasOwnProperty.call(
        data, "ownerIsPremium",
    );
    report.push({
      id: doc.id,
      name: data.name,
      ownerId: data.ownerId,
      hadFieldsBefore: hadFields,
    });
    if (!hadFields) {
      await syncFamilyAccessForOwner(data.ownerId);
    }
  }
  return {totalFamilies: familiesSnap.size, report};
});

exports.adminSetPremiumStatus = onCall(async (request) => {
  try {
    if (!request.auth || !ADMIN_EMAILS.includes(request.auth.token.email)) {
      throw new HttpsError(
          "permission-denied",
          "Funzione riservata all'amministratore.",
      );
    }

    const {targetUid, targetEmail, isPremium, trialDays, tier} =
      request.data || {};
    let uid = targetUid;
    if (!uid) {
      if (!targetEmail) {
        throw new HttpsError(
            "invalid-argument",
            "Specifica targetUid o targetEmail.",
        );
      }
      let user;
      try {
        user = await getAuth().getUserByEmail(
            String(targetEmail).trim().toLowerCase(),
        );
      } catch (e) {
        throw new HttpsError(
            "not-found",
            "Nessun utente registrato con questa email.",
        );
      }
      uid = user.uid;
    }

    const update = {};
    if (typeof isPremium === "boolean") {
      update.isPremium = isPremium;
    }
    if (typeof trialDays === "number" && trialDays > 0) {
      update.trialEnd = new Date(
          Date.now() + trialDays * 24 * 60 * 60 * 1000,
      ).toISOString();
    } else if (trialDays === 0) {
      // Revoca esplicita del trial (utile per testare il blocco accessi
      // del Blocco D senza aspettare una scadenza naturale).
      update.trialEnd = null;
    }
    if (tier === "famiglia" || tier === "premium") {
      update.subscriptionTier = tier;
    } else if (tier === null) {
      // Rimuove esplicitamente il tier Famiglia (torna al Premium base).
      update.subscriptionTier = FieldValue.delete();
    }
    if (Object.keys(update).length === 0) {
      throw new HttpsError(
          "invalid-argument",
          "Specifica isPremium, trialDays e/o tier.",
      );
    }

    await db.collection("users").doc(uid).set(update, {merge: true});
    // Blocco D: se uid è owner di una famiglia, sblocca/blocca subito
    // l'accesso familiare denormalizzato, senza aspettare un altro trigger.
    await syncFamilyAccessForOwner(uid);
    return {uid, ...update};
  } catch (error) {
    console.error("ERRORE ADMIN SET PREMIUM STATUS:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- ELIMINAZIONE COMPLETA ACCOUNT (amministrativa) ---
//
// Dato uid o email: cancella il documento users/{uid} con TUTTE le sue
// sottocollezioni (envelopes/expenses/incomes/challenges/
// recurringExpenses/notifications, via recursiveDelete) e l'account
// Firebase Auth corrispondente. Caso limite deciso esplicitamente con
// l'utente: se è owner di una famiglia con altri membri, l'INTERA
// famiglia viene eliminata (buste/spese/entrate/membri/inviti condivisi
// inclusi) insieme a lui — scelta distruttiva ma esplicita, non un
// trasferimento di proprietà implicito né un blocco silenzioso. Se invece
// è solo membro (non owner) di una famiglia altrui, viene rimosso solo il
// suo documento membro, la famiglia resta intatta per gli altri.
exports.deleteUserCompletely = onCall(async (request) => {
  try {
    if (!request.auth || !ADMIN_EMAILS.includes(request.auth.token.email)) {
      throw new HttpsError(
          "permission-denied",
          "Funzione riservata all'amministratore.",
      );
    }

    const {targetUid, targetEmail} = request.data || {};
    let uid = targetUid;
    if (!uid) {
      if (!targetEmail) {
        throw new HttpsError(
            "invalid-argument",
            "Specifica targetUid o targetEmail.",
        );
      }
      let user;
      try {
        user = await getAuth().getUserByEmail(
            String(targetEmail).trim().toLowerCase(),
        );
      } catch (e) {
        throw new HttpsError(
            "not-found",
            "Nessun utente registrato con questa email.",
        );
      }
      uid = user.uid;
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    // Famiglie di cui è owner: eliminate per intero (decisione esplicita).
    const ownedFamiliesSnap = await db.collection("families")
        .where("ownerId", "==", uid).get();
    for (const familyDoc of ownedFamiliesSnap.docs) {
      await db.recursiveDelete(familyDoc.ref);
    }

    // Se è solo membro di una famiglia altrui, rimuove solo il suo
    // documento membro — la famiglia e gli altri membri restano intatti.
    if (userData.familyId) {
      await db.collection("families").doc(userData.familyId)
          .collection("members").doc(uid).delete().catch(() => {
            // Già rimosso o famiglia già eliminata sopra: non bloccante.
          });
    }

    // Documento utente e tutte le sue sottocollezioni personali.
    await db.recursiveDelete(userRef);

    // Account Firebase Auth. "auth/user-not-found" non blocca: i dati
    // Firestore sono comunque già stati ripuliti sopra.
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if (e.code !== "auth/user-not-found") throw e;
    }

    return {
      uid,
      deletedOwnedFamilies: ownedFamiliesSnap.docs.map((d) => d.id),
    };
  } catch (error) {
    console.error("ERRORE DELETE USER COMPLETELY:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
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
    // Blocco D: un abbonamento reale attivato/scaduto deve riflettersi
    // subito sull'accesso familiare denormalizzato, se questo utente è
    // owner di una famiglia.
    await syncFamilyAccessForOwner(request.auth.uid);

    return {isPremium: isActive, expiryTime};
  } catch (error) {
    console.error("ERRORE VERIFY PLAY PURCHASE:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

// --- NOTIFICHE PUSH (Blocco 5 "post-beta"): avvisi Free giornalieri via
// regole/statistiche (zero costo AI, per tutti) + consiglio del giorno
// Premium/Trial proattivo (riusa generateAiInsight, stessa quota
// analisiAvanzateUsate). Token FCM salvato su users/{uid}.fcmToken dal
// client (NotificationService in lib/services/notification_service.dart,
// richiesto dopo il wizard di configurazione, mai al primissimo avvio).

/**
 * Invia una push (se l'utente ha un token salvato) e registra sempre la
 * notifica nello storico users/{uid}/notifications, consultabile dalla
 * schermata "Notifiche" anche se la notifica di sistema è già sparita.
 * @param {string} userId Uid del destinatario.
 * @param {FirebaseFirestore.DocumentReference} userRef Riferimento a
 *   users/{uid}.
 * @param {{title: string, body: string, type: string}} content Contenuto.
 * @param {string} fcmToken Token corrente dell'utente, o null/undefined se
 *   non ha mai attivato le notifiche su questo dispositivo.
 */
async function sendPushAndLog(userId, userRef, content, fcmToken) {
  await userRef.collection("notifications").add({
    title: content.title,
    body: content.body,
    type: content.type,
    read: false,
    createdAt: new Date().toISOString(),
  });

  if (!fcmToken) return;
  try {
    await getMessaging().send({
      token: fcmToken,
      notification: {title: content.title, body: content.body},
    });
  } catch (error) {
    console.error(`Push fallita per ${userId}:`, error.message);
    // Token scaduto/disinstallato: rimosso solo se l'errore lo conferma
    // esplicitamente, mai per un errore di rete generico.
    if (error.code === "messaging/registration-token-not-registered") {
      await userRef.set({fcmToken: FieldValue.delete()}, {merge: true});
    }
  }
}

const HIGH_USAGE_THRESHOLD = 0.85;
// Soglia fissa di giorni senza spese registrate prima del promemoria — non
// configurabile dall'utente per ora, coerente con la richiesta originale
// ("da N giorni"); facile da cambiare qui se in futuro serve renderla
// un'impostazione.
const NO_EXPENSE_REMINDER_DAYS = 5;

/**
 * Avvisi Free (busta esaurita/quasi esaurita, promemoria "nessuna spesa da
 * N giorni") per un singolo utente — stesse due condizioni già mostrate
 * nella card Home (budget_insights.dart), qui reimplementate in JS perché
 * devono girare anche per chi non apre l'app (budget_insights.dart resta
 * l'unica fonte per la card Home, questa è un secondo calcolo indipendente
 * con lo stesso risultato, non una duplicazione accidentale).
 * @param {string} userId Uid dell'utente.
 * @param {FirebaseFirestore.DocumentReference} userRef Riferimento a
 *   users/{uid}.
 * @param {object} userData Dati correnti del documento utente.
 */
async function checkUserFreeAlerts(userId, userRef, userData) {
  const fcmToken = userData.fcmToken;
  const monthKey = new Date().toISOString().slice(0, 7);
  const notifiedAlerts = userData.notifiedBudgetAlerts || {};
  const newlyNotified = {};

  const envelopesSnap = await userRef.collection("envelopes").get();
  for (const envDoc of envelopesSnap.docs) {
    const env = envDoc.data();
    const budget = Number(env.budget) || 0;
    const balance = Number(env.balance) || 0;
    if (budget <= 0) continue;

    let alertKey = null;
    let content = null;
    if (balance <= 0) {
      alertKey = `${envDoc.id}_esaurita`;
      content = {
        title: "Busta esaurita",
        body: `Hai esaurito la busta "${env.name}".`,
        type: "budget_alert",
      };
    } else {
      const percentUsed = (budget - balance) / budget;
      if (percentUsed >= HIGH_USAGE_THRESHOLD) {
        alertKey = `${envDoc.id}_soglia`;
        content = {
          title: "Busta quasi esaurita",
          body: `Hai già utilizzato il ${Math.round(percentUsed * 100)}% ` +
            `del budget "${env.name}".`,
          type: "budget_alert",
        };
      }
    }

    // Al più un avviso al mese per busta+condizione, altrimenti una busta
    // esaurita per settimane genererebbe una notifica ogni giorno.
    if (alertKey && notifiedAlerts[alertKey] !== monthKey) {
      await sendPushAndLog(userId, userRef, content, fcmToken);
      newlyNotified[alertKey] = monthKey;
    }
  }

  if (Object.keys(newlyNotified).length > 0) {
    await userRef.set({
      notifiedBudgetAlerts: {...notifiedAlerts, ...newlyNotified},
    }, {merge: true});
  }

  const expensesSnap = await userRef.collection("expenses")
      .orderBy("date", "desc").limit(1).get();
  if (expensesSnap.empty) return;
  const lastExpenseDate = new Date(expensesSnap.docs[0].data().date);
  const daysSinceLastExpense = Math.floor(
      (Date.now() - lastExpenseDate.getTime()) / 86400000,
  );
  // Uguaglianza esatta, non ">=": la funzione gira una volta al giorno,
  // quindi la soglia viene attraversata una sola volta. Il controllo su
  // notifiedNoExpenseDateKey resta comunque necessario per Cloud Scheduler
  // (consegna "at-least-once": una ri-consegna nello stesso giorno non deve
  // duplicare il promemoria — confermato con una ri-chiamata manuale sulla
  // stessa condizione durante il test su emulatore, che senza questo
  // controllo lo inviava una seconda volta).
  const todayKey = new Date().toISOString().slice(0, 10);
  if (daysSinceLastExpense === NO_EXPENSE_REMINDER_DAYS &&
      userData.notifiedNoExpenseDateKey !== todayKey) {
    await sendPushAndLog(userId, userRef, {
      title: "Nessuna spesa registrata",
      body: `Non registri una spesa da ${NO_EXPENSE_REMINDER_DAYS} giorni.`,
      type: "no_expense_reminder",
    }, fcmToken);
    await userRef.set({notifiedNoExpenseDateKey: todayKey}, {merge: true});
  }
}

/**
 * Consiglio del giorno inviato come push proattiva per chi ha Premium/Trial
 * attivo E ha un token FCM salvato (cioè ha attivato le notifiche) — stessa
 * quota condivisa analisiAvanzateUsate delle altre funzioni AI Premium,
 * stessa cache giornaliera di generateAiInsight (getOrGenerateDailyTip):
 * se l'utente ha già aperto l'app oggi e il consiglio è già in cache, non
 * viene rigenerato né consuma quota, solo inviato.
 * @param {string} userId Uid dell'utente.
 * @param {FirebaseFirestore.DocumentReference} userRef Riferimento a
 *   users/{uid}.
 * @param {object} userData Dati correnti del documento utente.
 */
async function sendPremiumDailyTipPush(userId, userRef, userData) {
  if (!userData.fcmToken) return; // notifiche mai attivate su nessun device
  const isPremium = userData.isPremium === true;
  const trialEnd = userData.trialEnd ? new Date(userData.trialEnd) : null;
  const isTrialActive = Boolean(trialEnd && trialEnd > new Date());
  if (!isPremium && !isTrialActive) return; // Free: nessun contenuto AI

  const todayKey = new Date().toISOString().slice(0, 10);
  if (userData.aiDailyTip && userData.aiDailyTip.pushedDateKey === todayKey) {
    return; // già inviata oggi (es. se la function fosse rilanciata)
  }

  try {
    const {text} =
      await getOrGenerateDailyTip(userId, userRef, userData, isPremium);
    if (!text) return;
    await sendPushAndLog(userId, userRef, {
      title: "Il tuo consiglio di oggi",
      body: text,
      type: "ai_daily_tip",
    }, userData.fcmToken);
    await userRef.set(
        {"aiDailyTip.pushedDateKey": todayKey}, {merge: true},
    );
  } catch (error) {
    // requireAnalisiQuotaAvailable può lanciare se la quota trial è
    // esaurita — qui non c'è un utente interattivo in attesa di un errore,
    // si salta silenziosamente al prossimo utente.
    console.error(
        `Push consiglio del giorno fallita per ${userId}:`, error.message,
    );
  }
}

exports.dailyScheduledChecks = onSchedule(
    {schedule: "0 9 * * *", timeZone: "Europe/Rome"},
    async () => {
      const usersSnap = await db.collection("users").get();
      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const userRef = userDoc.ref;
        const userData = userDoc.data();
        try {
          await checkUserFreeAlerts(userId, userRef, userData);
        } catch (error) {
          console.error(
              `checkUserFreeAlerts fallito per ${userId}:`, error.message,
          );
        }
        try {
          await sendPremiumDailyTipPush(userId, userRef, userData);
        } catch (error) {
          console.error(
              `sendPremiumDailyTipPush fallito per ${userId}:`, error.message,
          );
        }
      }
    },
);
