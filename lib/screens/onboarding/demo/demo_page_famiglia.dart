import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 9: presenta la funzione Famiglia già esistente — membri,
/// entrate/spese di ciascuno, mini statistica — senza inventare un
/// sistema alternativo.
class DemoPageFamiglia extends StatelessWidget {
  const DemoPageFamiglia({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Gestite il budget insieme',
          subtitle: 'Invita la tua famiglia: ognuno ha le proprie spese, '
              'tu vedi il quadro completo.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppIcon(
                      HeroIcons.users,
                      size: 18,
                      color: IconPalette.emerald,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Famiglia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: IconPalette.testo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const AppIcon(
                  HeroIcons.arrowDown,
                  size: 14,
                  color: IconPalette.accent,
                ),
                const SizedBox(height: 4),
                ...List.generate(demoFamilyMembers.length, (i) {
                  final m = demoFamilyMembers[i];
                  return DelayedEntrance(
                    delay: Duration(milliseconds: 250 + i * 180),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors
                                .envelopeColors[i % AppColors.envelopeColors.length]
                                .withValues(alpha: 0.15),
                            child: Text(
                              m.name[0],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.envelopeColors[
                                    i % AppColors.envelopeColors.length],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: IconPalette.testo,
                                  ),
                                ),
                                Text(
                                  m.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '€${m.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: IconPalette.testo,
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
        const SizedBox(height: 16),
        DelayedEntrance(
          delay: const Duration(milliseconds: 900),
          child: DemoCard(
            color: IconPalette.sfondoAlt,
            child: Row(
              children: const [
                AppIcon(
                  HeroIcons.sparkles,
                  size: 16,
                  color: IconPalette.amber,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spesa familiare totale: €2.585 questo mese',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
