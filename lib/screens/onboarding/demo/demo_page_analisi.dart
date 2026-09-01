import 'package:flutter/material.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 7: mini dashboard statistiche con barre per categoria che
/// crescono all'ingresso — dati demo, mai reali.
class DemoPageAnalisi extends StatelessWidget {
  const DemoPageAnalisi({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Capisci le tue abitudini',
          subtitle: 'Statistiche reali sulle tue spese, calcolate in '
              'automatico ogni mese.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spese del mese',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                      end: demoMonthTotal,
                      builder: (context, value) => Text(
                        '€${value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: IconPalette.testo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${demoMonthChangePercent.toStringAsFixed(0)}% '
                        'rispetto al mese scorso',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: IconPalette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DelayedEntrance(
          delay: const Duration(milliseconds: 400),
          child: DemoCard(
            child: Column(
              children: List.generate(demoCategorySlices.length, (i) {
                final s = demoCategorySlices[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CategoryIcon(type: s.category, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: IconPalette.testo,
                              ),
                            ),
                          ),
                          Text(
                            '${s.percent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: IconPalette.testo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedCounter(
                        end: s.percent / 100,
                        delay: Duration(milliseconds: 500 + i * 150),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, value) => DemoProgressBar(
                          value: value,
                          color: AppColors.envelopeColors[
                              i % AppColors.envelopeColors.length],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
