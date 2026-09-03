class AppUser {
  final bool isPremium;
  final bool isTrialActive;
  final DateTime? trialEnd;
  final int scontriniUsati;
  final int richiesteAiUsate;
  final int analisiAvanzateUsate;

  /// Token/prodotto dell'ultimo abbonamento Google Play verificato (scritti
  /// da verifyPlayPurchase). Usati per un ricontrollo periodico dello stato
  /// reale su Play senza dover aspettare un nuovo evento del purchaseStream
  /// (che uno store non ripresenta sempre spontaneamente, es. dopo una
  /// scadenza). Null se non è mai stato verificato un acquisto Play.
  final String? playPurchaseToken;
  final String? playProductId;

  /// Modello a due abbonamenti (2026-09-03, solo schema — nessun pagamento
  /// reale ancora): "famiglia" oppure null/altro (Premium base). Scrivibile
  /// solo da adminSetPremiumStatus via Admin SDK, mai dal client.
  final String? subscriptionTier;

  AppUser({
    required this.isPremium,
    required this.isTrialActive,
    this.trialEnd,
    required this.scontriniUsati,
    required this.richiesteAiUsate,
    required this.analisiAvanzateUsate,
    this.playPurchaseToken,
    this.playProductId,
    this.subscriptionTier,
  });

  bool get hasAiAccess => isPremium || isTrialActive;

  /// true se l'utente può creare/mantenere una famiglia: Trial attivo
  /// (anteprima completa) oppure Premium con tier "famiglia" — stessa
  /// logica di requireFamilyTierAccess lato server (functions/index.js).
  bool get hasFamilyTierAccess =>
      isTrialActive || (isPremium && subscriptionTier == 'famiglia');

  static const trialMaxScontrini = 30;
  static const trialMaxRichiesteAi = 50;
  static const trialMaxAnalisi = 10;

  bool get scontriniLimitReached =>
      !isPremium && isTrialActive && scontriniUsati >= trialMaxScontrini;
  bool get richiesteAiLimitReached =>
      !isPremium && isTrialActive && richiesteAiUsate >= trialMaxRichiesteAi;
}
