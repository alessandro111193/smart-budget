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

**Cloud Functions attive:** `chatWithAssistant`, `scanReceipt` (accetta `receiptImageBase64` e/o `productsImageBase64`, con `imageBase64` ancora supportato per compatibilità), `inviteFamilyMember`, `acceptFamilyInvite` — tutte con controllo auth + limiti trial. `verifyPlayPurchase` è scritta ma non operativa finché non è configurata su Play Console (vedi roadmap).

## Roadmap ancora da fare (in ordine)

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
