import '../widgets/app_icons.dart';

/// Dati statici di esempio per la mini demo interattiva dell'onboarding
/// (schermate 1-11). Puramente illustrativi: **non vengono mai salvati su
/// Firestore né passati a nessuna Cloud Function** — dopo la demo l'utente
/// inserisce i propri dati veri nella configurazione reale
/// (`lib/screens/onboarding/setup/`), che usa i servizi esistenti.

class DemoEnvelope {
  final String name;
  final double amount;
  final CategoryType category;
  const DemoEnvelope(this.name, this.amount, this.category);
}

const demoIncome = 2400.0;

const demoEnvelopes = [
  DemoEnvelope('Casa', 700, CategoryType.casa),
  DemoEnvelope('Spesa', 350, CategoryType.spesa),
  DemoEnvelope('Auto', 250, CategoryType.auto),
  DemoEnvelope('Famiglia', 300, CategoryType.famiglia),
  DemoEnvelope('Risparmio', 500, CategoryType.risparmio),
  DemoEnvelope('Svago', 200, CategoryType.svago),
  DemoEnvelope('Fondo imprevisti', 100, CategoryType.altro),
];

class DemoTransaction {
  final String label;
  final double amount;
  final CategoryType category;
  const DemoTransaction(this.label, this.amount, this.category);
}

const demoTransactions = [
  DemoTransaction('Supermercato', 45.30, CategoryType.spesa),
  DemoTransaction('Carburante', 35.00, CategoryType.carburante),
  DemoTransaction('Amazon', 28.90, CategoryType.tecnologia),
  DemoTransaction('Farmacia', 12.40, CategoryType.salute),
];

const demoSpesaBudget = 350.0;
const demoSpesaSpeso = 45.30;
const demoSpesaRimanente = demoSpesaBudget - demoSpesaSpeso;

class DemoShoppingItem {
  final String name;
  final bool checked;
  const DemoShoppingItem(this.name, this.checked);
}

const demoShoppingList = [
  DemoShoppingItem('Latte', true),
  DemoShoppingItem('Pasta', true),
  DemoShoppingItem('Uova', false),
  DemoShoppingItem('Frutta', false),
  DemoShoppingItem('Detersivo', false),
];

const demoShoppingBudget = 80.0;
const demoShoppingSpeso = 45.30;

const demoMonthTotal = 987.40;
const demoMonthChangePercent = -8.0;

class DemoCategorySlice {
  final String label;
  final double percent;
  final CategoryType category;
  const DemoCategorySlice(this.label, this.percent, this.category);
}

const demoCategorySlices = [
  DemoCategorySlice('Casa', 42, CategoryType.casa),
  DemoCategorySlice('Spesa', 28, CategoryType.spesa),
  DemoCategorySlice('Auto', 18, CategoryType.auto),
  DemoCategorySlice('Svago', 12, CategoryType.svago),
];

const demoGoalTitle = 'Vacanza';
const demoGoalTarget = 1200.0;
const demoGoalSaved = 600.0;
const demoGoalMonthlyQuota = 100.0;

class DemoFamilyMember {
  final String name;
  final String label;
  final double amount;
  const DemoFamilyMember(this.name, this.label, this.amount);
}

const demoFamilyMembers = [
  DemoFamilyMember('Alessandro (Padre)', 'Entrate', 2400),
  DemoFamilyMember('Selene (Moglie)', 'Spese personali', 120),
  DemoFamilyMember('Paolo (Figlio)', 'Scuola', 65),
];

class DemoChatMessage {
  final bool isUser;
  final String text;
  const DemoChatMessage(this.isUser, this.text);
}

const demoChatMessages = [
  DemoChatMessage(true, 'Come posso risparmiare questo mese?'),
  DemoChatMessage(false, 'Ho analizzato le tue spese.'),
  DemoChatMessage(
    false,
    'Questo mese hai speso il 18% in più per lo svago.',
  ),
  DemoChatMessage(
    false,
    'Potresti destinare €50 in più al risparmio.',
  ),
];

const demoAiPossibleSaving = 50.0;

/// Elenco esteso delle funzionalità Premium mostrate nella schermata
/// finale della demo, ognuna corrispondente a una funzionalità AI
/// realmente implementata (vedi CLAUDE.md, "AI Premium — consulente
/// personale", blocchi 1-9): mai una promessa non mantenuta dall'app.
class DemoPremiumFeature {
  final String emoji;
  final String label;
  const DemoPremiumFeature(this.emoji, this.label);
}

const demoPremiumFeatures = [
  DemoPremiumFeature('🤖', 'Consigli personalizzati'),
  DemoPremiumFeature('💰', 'Come distribuire lo stipendio nelle buste'),
  DemoPremiumFeature('📊', 'Analisi delle abitudini'),
  DemoPremiumFeature('🔮', 'Previsioni di spesa'),
  DemoPremiumFeature('💡', 'Suggerimenti per risparmiare'),
  DemoPremiumFeature('🎯', 'Pianificazione degli obiettivi'),
  DemoPremiumFeature('🏦', 'Gestione intelligente dei Sinking Funds'),
  DemoPremiumFeature('👨‍👩‍👧', 'Analisi familiare'),
  DemoPremiumFeature('🛒', 'Lista spesa intelligente'),
  DemoPremiumFeature('🧾', 'Analisi avanzata degli scontrini'),
  DemoPremiumFeature('💬', 'Chat con l\'assistente'),
  DemoPremiumFeature('📈', 'Report mensili automatici'),
  DemoPremiumFeature('🔔', 'Suggerimenti proattivi'),
];
