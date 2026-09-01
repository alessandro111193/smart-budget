import 'package:flutter/material.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 4: una mini lista di transazioni che compaiono una alla
/// volta, poi il collegamento visivo transazione -> categoria -> busta
/// -> saldo aggiornato.
class DemoPageSpese extends StatelessWidget {
  const DemoPageSpese({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Sai sempre dove finiscono i tuoi soldi',
          subtitle: 'Ogni spesa si aggancia subito alla busta giusta.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: DemoCard(
            child: Column(
              children: List.generate(demoTransactions.length, (i) {
                final t = demoTransactions[i];
                return DelayedEntrance(
                  delay: Duration(milliseconds: i * 160),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: IconPalette.testo,
                            ),
                          ),
                        ),
                        Text(
                          '-€${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: IconPalette.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          delay: const Duration(milliseconds: 750),
          child: DemoCard(
            color: IconPalette.sfondoAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '🛒 Spesa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IconPalette.testo,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '€${demoSpesaBudget.toStringAsFixed(0)} budget',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedCounter(
                  end: demoSpesaSpeso / demoSpesaBudget,
                  delay: const Duration(milliseconds: 950),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, value) =>
                      DemoProgressBar(value: value, color: IconPalette.orange),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Speso €${demoSpesaSpeso.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Rimanente €${demoSpesaRimanente.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: IconPalette.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
