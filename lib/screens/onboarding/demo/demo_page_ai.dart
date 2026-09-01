import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 10: mini conversazione con l'AI, con i messaggi che
/// compaiono in sequenza. Dati statici — **nessuna chiamata reale a
/// Gemini**, per non consumare la quota AI né avere un costo durante
/// l'onboarding.
class DemoPageAi extends StatelessWidget {
  const DemoPageAi({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'Un assistente che impara dalle tue abitudini',
          subtitle: 'Chiedigli quello che vuoi sul tuo budget, in '
              'linguaggio naturale.',
        ),
        const SizedBox(height: 18),
        ...List.generate(demoChatMessages.length, (i) {
          final m = demoChatMessages[i];
          return DelayedEntrance(
            delay: Duration(milliseconds: 250 + i * 450),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: m.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!m.isUser) ...[
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: IconPalette.primary,
                        child: AppIcon(
                          HeroIcons.sparkles,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: m.isUser
                              ? IconPalette.primary
                              : IconPalette.sfondoAlt,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(m.isUser ? 16 : 4),
                            bottomRight:
                                Radius.circular(m.isUser ? 4 : 16),
                          ),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: m.isUser
                                ? Colors.white
                                : IconPalette.testo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        DelayedEntrance(
          delay: Duration(milliseconds: 250 + demoChatMessages.length * 450),
          child: DemoCard(
            color: IconPalette.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const AppIcon(
                  HeroIcons.arrowTrendingUp,
                  color: IconPalette.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Possibile risparmio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '€${demoAiPossibleSaving.toStringAsFixed(0)} / mese',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
      ],
    );
  }
}
