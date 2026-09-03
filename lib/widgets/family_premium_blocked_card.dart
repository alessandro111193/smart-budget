import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/family.dart';
import '../screens/premium_screen.dart';
import 'app_icons.dart';

/// Blocco D (cambio modello di business Famiglia): card mostrata al posto
/// dei dati familiari quando il Premium/Trial dell'owner è scaduto — mai
/// un errore generico o uno schermo vuoto. Usata sia in `family_screen.dart`
/// sia in `family_dashboard_screen.dart`: estratta qui invece di duplicare
/// il testo in due file, per non rischiare che i due messaggi divergano in
/// futuro. Nessun dato viene mai cancellato, solo bloccato in lettura.
class FamilyPremiumBlockedCard extends StatelessWidget {
  const FamilyPremiumBlockedCard({super.key, required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(HeroIcons.lockClosed, color: AppColors.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Premium della famiglia scaduto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Il tuo Premium (o Trial) è scaduto: riattivalo per '
                      'tornare ad accedere a buste, spese ed entrate della '
                      'tua famiglia. Nessun dato è stato cancellato.'
                : 'Il Premium del proprietario di questa famiglia è '
                      'scaduto: deve riattivarlo per ripristinare l\'accesso '
                      'ai dati della famiglia. Nessun dato è stato '
                      'cancellato.',
            style: const TextStyle(fontSize: 13, color: AppColors.neutral),
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PremiumScreen()),
                ),
                child: const Text('Vai a Premium'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wrapper di comodo: dato un [family], decide se mostrare [child] (accesso
/// attivo) o la card di blocco (accesso scaduto) — evita di ripetere lo
/// stesso `if` in ogni schermata che mostra dati familiari.
class FamilyAccessGate extends StatelessWidget {
  const FamilyAccessGate({
    super.key,
    required this.family,
    required this.myUid,
    required this.title,
    required this.child,
  });

  final Family family;
  final String? myUid;

  /// Nome della famiglia, mostrato sopra la card di blocco (stesso posto
  /// in cui comparirebbe normalmente il titolo della schermata).
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (family.accessActive) return child;
    final isOwner = family.ownerId == myUid;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FamilyPremiumBlockedCard(isOwner: isOwner),
        ],
      ),
    );
  }
}
