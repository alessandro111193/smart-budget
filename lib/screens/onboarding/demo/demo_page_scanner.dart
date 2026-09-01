import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 5: demo puramente visiva dello scanner scontrino (foto ->
/// scansione -> risultato riconosciuto). Non chiama in alcun modo la
/// vera Cloud Function `scanReceipt` — quella logica resta invariata,
/// questa è solo una vetrina con dati finti.
class DemoPageScanner extends StatelessWidget {
  const DemoPageScanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Una foto e hai già fatto metà del lavoro',
          subtitle: 'Scatta lo scontrino, l\'AI riconosce prodotti e '
              'prezzi da sola.',
        ),
        const SizedBox(height: 28),
        DelayedEntrance(
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: IconPalette.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const AppIcon(
                HeroIcons.receiptPercent,
                size: 44,
                color: IconPalette.purple,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DelayedEntrance(
          delay: const Duration(milliseconds: 400),
          child: const Center(
            child: AppIcon(
              HeroIcons.arrowDown,
              color: IconPalette.accent,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DelayedEntrance(
          delay: const Duration(milliseconds: 550),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  HeroIcons.qrCode,
                  size: 18,
                  color: IconPalette.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scansione in corso…',
                  style: TextStyle(
                    fontSize: 13,
                    color: IconPalette.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          delay: const Duration(milliseconds: 900),
          child: DemoCard(
            child: Row(
              children: [
                CategoryIcon(type: CategoryType.spesa, size: 44),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supermercato',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: IconPalette.testo,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Riconosciuto automaticamente',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '€45,30',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: IconPalette.testo,
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
