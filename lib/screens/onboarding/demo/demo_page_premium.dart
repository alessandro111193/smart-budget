import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 11 (ultima): presenta il valore di Premium con un mascotte
/// robot animato (`FloatingBounce`, solo Flutter nativo) e l'elenco
/// completo delle funzionalità AI realmente implementate (vedi
/// `demoPremiumFeatures` in `onboarding_demo_data.dart`, allineato ai 9
/// blocchi "AI Premium" descritti in CLAUDE.md). Non effettua alcun
/// acquisto: è solo una vetrina, l'acquisto vero avviene nella schermata
/// Premium reale.
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
        const SizedBox(height: 12),
        DelayedEntrance(
          child: Center(
            child: FloatingBounce(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [IconPalette.purple, IconPalette.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IconPalette.purple.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Text('🤖', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        DelayedEntrance(
          delay: const Duration(milliseconds: 100),
          child: DemoCard(
            padding: const EdgeInsets.all(18),
            color: IconPalette.sfondoAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppIcon(
                      HeroIcons.star,
                      solid: true,
                      color: IconPalette.purple,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cosa puoi fare con Premium',
                      style: TextStyle(
                        color: IconPalette.testo,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(demoPremiumFeatures.length, (i) {
                    final f = demoPremiumFeatures[i];
                    return DelayedEntrance(
                      delay: Duration(milliseconds: 150 + i * 70),
                      offsetY: 0.04,
                      child: _FeatureChip(emoji: f.emoji, label: f.label),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
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

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: IconPalette.testo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
