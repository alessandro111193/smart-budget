import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 11: presenta il valore di Premium usando solo funzionalità
/// realmente implementate (vedi `demoPremiumFeatures` in
/// `onboarding_demo_data.dart`, allineato a `premium_screen.dart`). Non
/// effettua alcun acquisto: è solo una vetrina, l'acquisto vero avviene
/// nella schermata Premium reale.
class DemoPagePremium extends StatelessWidget {
  const DemoPagePremium({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Vuoi andare oltre?',
          subtitle: 'Con Premium l\'AI diventa il tuo consulente '
              'personale di spesa.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [IconPalette.purple, IconPalette.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: IconPalette.purple.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppIcon(HeroIcons.star, solid: true, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Spesa Intelligente Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(demoPremiumFeatures.length, (i) {
                  return DelayedEntrance(
                    delay: Duration(milliseconds: 200 + i * 90),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const AppIcon(
                            HeroIcons.checkCircle,
                            solid: true,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            demoPremiumFeatures[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Potrai attivare Premium in qualunque momento dalla scheda '
          'dedicata: qui continuiamo con la configurazione gratuita.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
