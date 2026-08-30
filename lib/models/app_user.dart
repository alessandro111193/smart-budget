class AppUser {
  final bool isPremium;
  final bool isTrialActive;
  final DateTime? trialEnd;
  final int scontriniUsati;
  final int richiesteAiUsate;
  final int analisiAvanzateUsate;

  AppUser({
    required this.isPremium,
    required this.isTrialActive,
    this.trialEnd,
    required this.scontriniUsati,
    required this.richiesteAiUsate,
    required this.analisiAvanzateUsate,
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
