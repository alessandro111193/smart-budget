import 'package:flutter/material.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 2: una mini Home animata — gli stessi numeri che l'utente
/// vedrà nella propria Home, ma con dati demo che contano su mentre
/// compaiono.
class DemoPageMiniHome extends StatelessWidget {
  const DemoPageMiniHome({super.key});

  static const _spese = 980.0;
  static const _risparmio = 440.0;
  static const _disponibile = 1420.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Tutto sotto controllo',
          subtitle: 'La tua Home mostra sempre, in un colpo d\'occhio, '
              'quanto puoi ancora spendere.',
        ),
        const SizedBox(height: 24),
        DelayedEntrance(
          child: AnimatedCounter(
            end: _disponibile,
            duration: const Duration(milliseconds: 1100),
            builder: (context, value) => DemoBalanceCard(
              disponibile: value,
              entrate: value / _disponibile * demoIncome,
              spese: value / _disponibile * _spese,
            ),
          ),
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          delay: const Duration(milliseconds: 500),
          child: const Text(
            'Le tue buste',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 10),
        DelayedEntrance(
          delay: const Duration(milliseconds: 600),
          child: DemoCard(
            child: Column(
              children: demoEnvelopes
                  .take(4)
                  .map(
                    (e) => DemoEnvelopeRow(
                      name: e.name,
                      amount: e.amount,
                      category: e.category,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DelayedEntrance(
          delay: const Duration(milliseconds: 900),
          child: const DemoProgressBar(value: _risparmio / demoIncome),
        ),
        const SizedBox(height: 6),
        DelayedEntrance(
          delay: const Duration(milliseconds: 950),
          child: const Text(
            'Risparmio del mese: €440',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
