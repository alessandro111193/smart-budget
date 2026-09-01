import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 3: un'entrata che si distribuisce visivamente nelle buste,
/// una dopo l'altra — lo stesso concetto di "cash stuffing digitale"
/// alla base dell'app, mostrato invece che spiegato.
class DemoPageBuste extends StatelessWidget {
  const DemoPageBuste({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Ogni euro ha una destinazione',
          subtitle: 'Appena arriva un\'entrata, la dividi subito tra le '
              'tue buste.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: Center(
            child: AnimatedCounter(
              end: demoIncome,
              duration: const Duration(milliseconds: 700),
              builder: (context, value) => Text(
                '€${value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: IconPalette.testo,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        DelayedEntrance(
          delay: const Duration(milliseconds: 500),
          child: const Center(
            child: AppIcon(
              HeroIcons.arrowDown,
              color: IconPalette.accent,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(demoEnvelopes.length, (i) {
          final e = demoEnvelopes[i];
          return DelayedEntrance(
            delay: Duration(milliseconds: 650 + i * 110),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DemoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: DemoEnvelopeRow(
                  name: e.name,
                  amount: e.amount,
                  category: e.category,
                  dense: true,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        DelayedEntrance(
          delay: Duration(milliseconds: 650 + demoEnvelopes.length * 110 + 200),
          child: const Text(
            'Così sai sempre quanto puoi spendere.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IconPalette.primary,
            ),
          ),
        ),
      ],
    );
  }
}
