# Spesa Intelligente — Contesto progetto per Claude Code

## Cos'è
App Flutter + Firebase di gestione budget familiare basata su "cash stuffing digitale": ogni entrata viene distribuita tra buste prima di essere spesa. Modello Free (analisi via regole, no AI) / Premium (AI generativa, scanner scontrino, previsioni).

## Regole obbligatorie — NON derogabili
- Prima di modificare codice, analizza il repository esistente. Non riscrivere da zero.
- Non eliminare funzionalità esistenti senza spiegare perché.
- Per ogni modifica indica: file, problema, soluzione, rischio, test.
- Procedi per piccoli blocchi, verifica la compilazione (`flutter analyze` + build) dopo ogni blocco.
- L'AI passa SEMPRE da Cloud Functions. Mai chiavi API nel client Flutter, mai hardcoded nel codice — solo `functions/.env`.
- Free non fa mai chiamate AI (costo zero). Premium/Trial sì, con limiti verificati **lato server**, non solo in Flutter.
- Le Firestore Rules isolano i dati per utente e per famiglia — mai lettura/scrittura di dati non propri.
- Se una scelta tecnica è incerta, fermati e proponi alternative invece di introdurre una soluzione fragile.
- Ambiente di sviluppo: Ubuntu. Emulatori Firebase locali per lo sviluppo, connessione reale solo in build release (già gestito in `main.dart` con `kDebugMode`).

## Design System
- Colori: verde `#16B98C` (primario), blu `#2563EB`, viola `#8B5CF6`, arancio `#F59E0B`, rosso `#EF4444`, grigio `#64748B`
- Font: Poppins via `google_fonts` (`AppTheme.light()` in `lib/theme/app_theme.dart` imposta `GoogleFonts.poppinsTextTheme()` come `textTheme` globale del `MaterialApp`, quindi ogni `Text` lo eredita automaticamente salvo `fontFamily` esplicito — verificato presente e coerente su tutto il progetto)
- Componenti: card arrotondate (elevation 0, `color: Color(0xFFF8FAFC)`, `borderRadius` 14–16), icone circolari colorate (`CircleAvatar` + `color.withOpacity(0.12–0.15)`), campi di testo filled/rounded (`filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: circular(14)), borderSide: BorderSide.none`), AppBar bianca/elevation 0/testo e icone `AppColors.ink`, bottoni primari full-width arrotondati (`borderRadius` 14, testo bold, `foregroundColor: Colors.white`), progress bar sempre dentro `ClipRRect(borderRadius: circular(4))`
- Mantenere coerenza grafica in ogni nuova schermata — nessuna pagina fuori stile. Schermate allineate: Home, Buste, Spese, Statistiche, Premium, Scanner scontrino, Lista della spesa, AI Chat, Challenge/Sinking Funds, tutte le schermate Famiglia.

## Stato attuale — cosa è già costruito e funzionante

**Struttura:** `lib/models`, `lib/screens`, `lib/services`, `lib/theme`, `lib/widgets`, `functions/index.js`

**Modelli:** `Envelope`, `Expense`, `Income` (con allocazioni), `Challenge` (`ChallengeType.saving/spendingLimit`, con `envelopeId` opzionale per i Sinking Funds), `AppUser` (Premium/Trial + contatori uso), `Family`/`FamilyMember`/`FamilyInvite`, `FamilyExpense` (personale/condivisa/ripartita, senza doppio conteggio), `FamilyIncome`

**Schermate:** Login, Home (dashboard fedele al mockup ufficiale), Buste, Spese (elenco filtrato+raggruppato), Statistiche (grafico a ciambella `fl_chart`), Challenge (con sezione Sinking Funds), Premium (card con trial/stato abbonamento), AI Chat (chiama davvero `chatWithAssistant` passando un `spendingSummary` compatto costruito lato client — spese del mese corrente aggregate per categoria, entrate/spese totali del mese, quota mensile dei Sinking Funds attivi; niente transazioni singole né dati familiari, per tenere bassi i token e il costo per richiesta), Scanner scontrino (foto scontrino e/o foto prodotti, con abbinamento AI prodotto↔prezzo↔quantità quando entrambe le foto sono fornite; auto-creazione buste se l'utente non ne ha ancora, altrimenti selezione busta obbligatoria prima del salvataggio — mai un default silenzioso), Lista della spesa intelligente (suggerimenti basati sulla frequenza d'acquisto nello storico spese, nessuna chiamata AI quindi disponibile anche su Free; aggiunta manuale articoli), Famiglia (creazione, inviti via Cloud Function, membri, dashboard con filtro Famiglia/Membro, buste ed entrate familiari)

**Sicurezza:** Firestore Rules per utenti e famiglie; Cloud Functions con verifica auth + Premium/Trial server-side; chiavi solo in `functions/.env`; `main.dart` con emulatori solo in debug. Lo stato della lista della spesa (`shoppingListChecked`, `shoppingListManualItems`) è salvato sul documento utente esistente proprio per restare coperto dalle regole già in vigore, senza doverle allargare.

**AI Premium — consulente personale (in corso, piano approvato, si procede a blocchi):** vedi la roadmap sotto per l'elenco completo. Blocco 1 completato: `lib/services/budget_insights.dart` calcola avvisi di budget solo con regole/statistiche (busta esaurita, ≥85% di utilizzo, proiezione di fine mese al ritmo di spesa attuale) — zero chiamate AI, disponibili anche su Free, mostrati in una card su `home_screen.dart` (`_budgetAlertsCard`) solo quando ci sono avvisi da mostrare.

**Cloud Functions attive:** `chatWithAssistant`, `scanReceipt` (accetta `receiptImageBase64` e/o `productsImageBase64`, con `imageBase64` ancora supportato per compatibilità), `inviteFamilyMember`, `acceptFamilyInvite` — tutte con controllo auth + limiti trial. `verifyPlayPurchase` è scritta ma non operativa finché non è configurata su Play Console (vedi roadmap).

## Roadmap ancora da fare (in ordine)

0. **AI Premium — consulente personale di spesa intelligente**, in blocchi sequenziali (piano approvato):
   1. ~~Alert proattivi su buste/budget~~ — **fatto** (`budget_insights.dart`, Dart/Firestore, zero costo, anche Free).
   2. ~~Infrastruttura AI Premium condivisa~~ — **fatto**. `functions/index.js` ha ora `requireActiveAccess(userData)` (estratto da `chatWithAssistant`/`scanReceipt`, che ora lo riusano invece di duplicare il controllo), `requireAnalisiQuotaAvailable(userData, isPremium)` e `incrementAnalisiQuota(userRef)` sul contatore condiviso `analisiAvanzateUsate` (limite trial 10/mese, `TRIAL_MAX_ANALISI_AVANZATE` — va tenuto allineato a mano con `AppUser.trialMaxAnalisi` in Dart, stesso pattern già in uso per gli altri due contatori). Nuova Cloud Function `generateAiInsight`, per ora con un solo `kind` di prova ("test_echo"): i kind reali (`daily_tip`, `monthly_report`, `habit_analysis`, `family_analysis`) si aggiungono nei blocchi successivi. **Tutte le funzioni AI Premium proattive dei blocchi 3-9 useranno questo stesso contatore**, mai uno separato per funzionalità.
   3. ~~Distribuzione entrate assistita~~ — **fatto**. Cloud Function `suggestIncomeDistribution` (output strutturato con `responseSchema`, enum sui veri `envelopeId` come in `scanReceipt`, normalizzazione server-side per garantire che la somma non superi mai l'entrata dichiarata anche se il modello arrotonda male). Cablata in `new_income_screen.dart`: bottone "Consiglio AI per la distribuzione" (solo Premium/Trial) che costruisce un riepilogo compatto (buste con budget/saldo/% usata + quota mensile degli obiettivi di risparmio attivi, niente storico completo), mostra la proposta con motivazione, e la applica ai campi del form **solo** dopo tap su "Applica distribuzione" — il salvataggio resta comunque un'azione separata dell'utente. Copre solo l'ingresso da nuova entrata (punto 2); l'ingresso "chiedilo in chat" (punto 6) resta disponibile in prosa tramite `chatWithAssistant` già esistente, senza bottone azionabile — valutare in futuro se serve anche lì.
   4. ~~Contenuti AI proattivi con cache~~ — **fatto**. `generateAiInsight` gestisce ora anche `kind: "daily_tip"` e `kind: "monthly_report"`: aggrega i dati del mese corrente lato server (nuovo helper `buildPersonalMonthlySummary`, stessa logica già usata lato client in `ai_chat_screen.dart` ma eseguita con l'Admin SDK), chiama Gemini con `responseSchema` dedicato, scrive il risultato in cache su `users/{uid}` (`aiDailyTip: {text, dateKey}`, `aiMonthlyReport: {puntoDiForza, attenzione, consiglio, totalEntrate, totalSpeso, monthKey}`) e — se la cache per il giorno/mese corrente è già valida — la restituisce **senza richiamare Gemini né consumare la quota condivisa**, verificato negli emulatori. "Consiglio di oggi" ora è reale in `home_screen.dart` (`_DailyTipContent`, sostituisce il testo statico); "Il mio mese secondo l'AI" è una card espandibile in cima a `ai_chat_screen.dart` (`_MonthlyReportCard`), con i tre numeri (entrate/spese/risparmio) sempre calcolati in Dart/Firestore e solo le tre frasi narrate da Gemini.
   5. ~~Analisi abitudini e consigli di risparmio narrati~~ — **fatto**. `lib/services/habit_insights.dart` calcola in Dart, zero costo, la media mensile per categoria sugli ultimi 6 mesi completi (esclude il mese in corso) e le variazioni ≥20% dell'ultimo mese rispetto alla media precedente; se lo storico è insufficiente (meno di 2 mesi completi) restituisce una stringa vuota e l'AI non viene proprio chiamata. `generateAiInsight` gestisce `kind: "habit_analysis"` (riceve il riepilogo dal client, on-demand, nessuna cache — coerente col fatto che non è tra i contenuti proattivi del Blocco 4). Card "Analisi abitudini di spesa" in `analysis_screen.dart` (Statistiche), visibile solo Premium/Trial, richiede un tap esplicito — mai generata da sola all'apertura schermo.
   6. Obiettivi intelligenti — la quota mensile e il check "on track" sono già implementati in `Challenge.monthlyQuota` (usato anche dai Sinking Funds); resta solo da valutare, a bassa priorità, il parsing di un obiettivo scritto in linguaggio naturale.
   7. Scanner scontrino: confronto con la media storica di categoria dopo lo scan (Dart/Firestore, non tocca la conferma manuale esistente).
   8. Insight famiglia (confronto mese su mese via Dart, narrazione opzionale, mai giudizi sulle persone).
   9. Lista della spesa assistita da budget + arricchimento del contesto passato alla chat — priorità più bassa.

   Piano completo con la tabella di classificazione Dart/Firestore vs Gemini per ogni punto: `/home/alessandro/.claude/plans/binary-soaring-blanket.md`.

1. **Fase 6a — Google Play Billing (plumbing pronto, in attesa di configurazione Play Console):** codice client (`lib/services/billing_service.dart`, integrato in `premium_screen.dart`) e Cloud Function di verifica server-side (`verifyPlayPurchase` in `functions/index.js`) già scritti, ma **non testabili né utilizzabili finché non fai tu, sul tuo account Google Play Console:**
   - decidere l'`applicationId` Android definitivo (oggi è ancora il placeholder `com.example.smart_budget` in `android/app/build.gradle.kts` — non l'ho toccato perché legarlo a un valore diverso è una scelta solo tua, e va coordinato con l'app Android già registrata su Firebase);
   - creare in Play Console un prodotto abbonamento (subscription) e comunicarmi il suo ID reale, da mettere al posto del placeholder `premium_monthly` in `lib/services/billing_service.dart`;
   - creare un service account con accesso alla Play Developer API e mettere il suo JSON in `functions/.env` come `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, più `ANDROID_PACKAGE_NAME` con l'applicationId scelto sopra. Finché queste due variabili mancano, `verifyPlayPurchase` rifiuta esplicitamente la richiesta (non finge mai che un acquisto sia valido).

   Il trial simulato via Firestore (`FirestoreService.startTrial`) resta invariato come percorso di sviluppo/test in emulatore, in parallelo al bottone "Abbonati subito su Google Play" (visibile solo se lo store è disponibile, cioè non sul Web). **Qualunque test con acquisti reali o account/carte reali va fatto da te — io non posso e non devo eseguirlo.**
2. **Fase 6b — AdMob (plumbing pronto, in attesa di configurazione AdMob Console):** `lib/services/ad_service.dart` + `lib/widgets/free_ad_banner.dart` gestiscono un banner mostrato solo agli utenti Free (né Premium né Trial attivo), cablato in `bottom_nav_shell.dart` sopra la bottom navigation bar (visibile su tutte le tab). Usa gli **ID di test ufficiali di Google** (sicuri, non richiedono un account AdMob, non generano mai pubblicità vera) sia nel codice Dart sia nei manifest nativi (`android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`). **Prima della pubblicazione** serve che tu crei un'app AdMob reale (Android, ed eventualmente iOS) con almeno un ad unit "Banner", e mi passi: App ID AdMob e ad unit ID banner. Finché restano gli ID di test, l'app mostra sempre banner di test — mai pubblicità vera.
3. **Fase 7 — Servizi esterni (più avanti, non prioritario):** moduli assicurazioni/energia come da business plan, solo dopo validazione con utenti reali
4. **Pubblicazione:** Google Play Console, test chiuso 12 tester/14 giorni, privacy policy

## Problemi noti
- `test/widget_test.dart` fallisce sempre (`[core/no-app] No Firebase App '[DEFAULT]' has been created`): lo smoke test istanzia `SmartBudgetApp` senza prima chiamare `Firebase.initializeApp()`/mock. Non bloccante per lo sviluppo corrente ma da sistemare prima di affidarsi a `flutter test` in CI.

## Note economiche/di prodotto da rispettare nelle scelte tecniche
- Modello Gemini: `gemini-3.5-flash-lite` per le chiamate correnti (verificato disponibile)
- Costo AI target: sotto €0,15/utente Premium/mese — instradare verso il modello più economico possibile per ogni tipo di richiesta
- Non salvare le foto scontrino originali dopo l'elaborazione, salvo scelta esplicita dell'utente (risparmio storage)
