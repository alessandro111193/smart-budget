import 'package:shared_preferences/shared_preferences.dart';

/// Ricorda, solo su questo dispositivo (non per account), se l'onboarding
/// introduttivo è già stato mostrato — così compare una volta sola, anche
/// se l'utente non ha ancora effettuato l'accesso la prima volta.
class OnboardingService {
  static const _seenKey = 'onboarding_seen';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
