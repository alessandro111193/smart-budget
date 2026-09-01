import 'package:firebase_analytics/firebase_analytics.dart';

/// Wrapper unico per Firebase Analytics: ogni evento richiesto dal piano di
/// beta readiness (apertura app, registrazione, login, creazione busta,
/// spesa, entrata, utilizzo AI/scanner/lista spesa, famiglia, trial,
/// acquisto Premium) ha qui un metodo dedicato, così è facile verificare a
/// colpo d'occhio che NESSUN parametro contenga dati finanziari personali
/// (importi, descrizioni, categorie testuali) o altri dati sensibili: solo
/// nomi evento e, dove utile, piccoli tag strutturali (es. "personal" vs
/// "family", il nome della funzione AI usata).
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logAppOpen() => _analytics.logAppOpen();

  static Future<void> logSignUp() =>
      _analytics.logSignUp(signUpMethod: 'email');

  static Future<void> logLogin() =>
      _analytics.logLogin(loginMethod: 'email');

  static Future<void> logEnvelopeCreated({required bool isFamily}) =>
      _analytics.logEvent(
        name: 'envelope_created',
        parameters: {'scope': isFamily ? 'family' : 'personal'},
      );

  static Future<void> logExpenseAdded({required bool isFamily}) =>
      _analytics.logEvent(
        name: 'expense_added',
        parameters: {'scope': isFamily ? 'family' : 'personal'},
      );

  static Future<void> logIncomeAdded({required bool isFamily}) =>
      _analytics.logEvent(
        name: 'income_added',
        parameters: {'scope': isFamily ? 'family' : 'personal'},
      );

  /// [feature] identifica solo QUALE funzione AI è stata usata (es. "chat",
  /// "scan_receipt", "income_distribution", "shopping_list", "insight"),
  /// mai il contenuto della richiesta o della risposta.
  static Future<void> logAiFeatureUsed(String feature) => _analytics.logEvent(
    name: 'ai_feature_used',
    parameters: {'feature': feature},
  );

  static Future<void> logScannerUsed() =>
      _analytics.logEvent(name: 'scanner_used');

  static Future<void> logShoppingListUsed() =>
      _analytics.logEvent(name: 'shopping_list_used');

  static Future<void> logFamilyCreated() =>
      _analytics.logEvent(name: 'family_created');

  static Future<void> logFamilyMemberInvited() =>
      _analytics.logEvent(name: 'family_member_invited');

  static Future<void> logTrialStarted() =>
      _analytics.logEvent(name: 'trial_started');

  static Future<void> logPremiumPurchased() =>
      _analytics.logEvent(name: 'premium_purchased');
}
