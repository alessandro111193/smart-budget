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

  AppUser({
    required this.isPremium,
    required this.isTrialActive,
    this.trialEnd,
    required this.scontriniUsati,
    required this.richiesteAiUsate,
    required this.analisiAvanzateUsate,
    this.playPurchaseToken,
    this.playProductId,
  });

  bool get hasAiAccess => isPremium || isTrialActive;

  static const trialMaxScontrini = 30;
  static const trialMaxRichiesteAi = 50;
  static const trialMaxAnalisi = 10;

  bool get scontriniLimitReached =>
      !isPremium && isTrialActive && scontriniUsati >= trialMaxScontrini;
  bool get richiesteAiLimitReached =>
      !isPremium && isTrialActive && richiesteAiUsate >= trialMaxRichiesteAi;
}
