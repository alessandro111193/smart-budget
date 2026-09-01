import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 1: benvenuto — logo, titolo, e una prima composizione
/// grafica in miniatura dell'app (card disponibilità + buste + AI) che
/// compare a pezzi, per dare da subito la sensazione "sto guardando
/// l'app", non un tutorial.
class DemoPageWelcome extends StatelessWidget {
  const DemoPageWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        DelayedEntrance(
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: IconPalette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                HeroIcons.wallet,
                size: 34,
                color: IconPalette.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          delay: const Duration(milliseconds: 80),
          child: const Text(
            'Il tuo denaro. Più semplice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: IconPalette.testo,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DelayedEntrance(
          delay: const Duration(milliseconds: 160),
          child: const Text(
            'Organizza il tuo budget, controlla le spese e raggiungi i '
            'tuoi obiettivi in un unico posto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 28),
        DelayedEntrance(
          delay: const Duration(milliseconds: 260),
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Disponibile',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                AnimatedCounter(
                  end: demoIncome,
                  delay: const Duration(milliseconds: 350),
                  builder: (context, value) => Text(
                    '€${value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: IconPalette.testo,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: demoEnvelopes.take(4).map((e) {
                    return Expanded(
                      child: DelayedEntrance(
                        delay: Duration(
                          milliseconds:
                              500 + demoEnvelopes.indexOf(e) * 90,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                          ),
                          child: CategoryIcon(
                            type: e.category,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                DelayedEntrance(
                  delay: const Duration(milliseconds: 900),
                  child: Row(
                    children: [
                      const AppIcon(
                        HeroIcons.sparkles,
                        size: 14,
                        color: IconPalette.amber,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Un assistente AI ti aiuta a risparmiare',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
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
