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
//   - "family_analysis" (Blocco 8): riceverà anch'esso un summary
//     compatto costruito lato client.

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

exports.generateAiInsight = onCall({timeoutSeconds: 120}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }
    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};
    const now = new Date();

    // Accesso Premium/Trial richiesto sempre, anche per servire dalla
    // cache: resta comunque una funzionalità Premium.
    const {isPremium} = requireActiveAccess(userData);

    const kind = request.data.kind;

    if (kind === "daily_tip") {
      const todayKey = now.toISOString().slice(0, 10); // yyyy-MM-dd
      const cached = userData.aiDailyTip;
      if (cached && cached.dateKey === todayKey) {
        return {kind, text: cached.text, cached: true};
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
      const parsed = JSON.parse(result.response.text());
      const text = typeof parsed.text === "string" ? parsed.text : "";

      await userRef.set({
        aiDailyTip: {
          text, dateKey: todayKey, generatedAt: now.toISOString(),
        },
      }, {merge: true});
      await incrementAnalisiQuota(userRef);

      return {kind, text, cached: false};
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
          "con quota mensile indicata. Aggiungi \"motivazione\": una " +
          "sola frase breve in italiano che spieghi la logica principale " +
          "della proposta.";

        const result = await model.generateContent(prompt);
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
