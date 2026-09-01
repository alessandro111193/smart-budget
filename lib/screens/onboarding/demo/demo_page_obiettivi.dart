import 'package:flutter/material.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 8: un obiettivo di risparmio con la progress bar che
/// avanza da 0 al 50% reale dell'esempio.
class DemoPageObiettivi extends StatelessWidget {
  const DemoPageObiettivi({super.key});

  static const _percent = demoGoalSaved / demoGoalTarget;
  static const _missing = demoGoalTarget - demoGoalSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Trasforma i tuoi obiettivi in un piano',
          subtitle: 'Imposta un traguardo, l\'app calcola quanto '
              'accantonare ogni mese.',
        ),
        const SizedBox(height: 24),
        DelayedEntrance(
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryIcon(type: CategoryType.viaggi, size: 44),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Vacanza',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: IconPalette.testo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _amountColumn('Obiettivo', demoGoalTarget),
                    _amountColumn('Risparmiato', demoGoalSaved),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedCounter(
                  end: _percent,
                  delay: const Duration(milliseconds: 350),
                  duration: const Duration(milliseconds: 1100),
                  builder: (context, value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DemoProgressBar(value: value, height: 10),
                      const SizedBox(height: 6),
                      Text(
                        '${(value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: IconPalette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        DelayedEntrance(
          delay: const Duration(milliseconds: 1500),
          child: DemoCard(
            color: IconPalette.sfondoAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ti mancano €${_missing.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IconPalette.testo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puoi raggiungerlo mettendo da parte '
                  '€${demoGoalMonthlyQuota.toStringAsFixed(0)} al mese.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountColumn(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          '€${value.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: IconPalette.testo,
          ),
        ),
      ],
    );
  }
}
