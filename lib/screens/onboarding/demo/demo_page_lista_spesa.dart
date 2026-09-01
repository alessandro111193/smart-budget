import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../data/onboarding_demo_data.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Schermata 6: mini lista della spesa con voci che si spuntano da sole,
/// più il budget collegato — stessa logica della vera lista della spesa
/// (disponibile anche su Free).
class DemoPageListaSpesa extends StatefulWidget {
  const DemoPageListaSpesa({super.key});

  @override
  State<DemoPageListaSpesa> createState() => _DemoPageListaSpesaState();
}

class _DemoPageListaSpesaState extends State<DemoPageListaSpesa> {
  late final List<bool> _checked =
      demoShoppingList.map((i) => i.checked).toList();

  @override
  void initState() {
    super.initState();
    // Anima la spunta di "Uova" per far vedere l'interazione, senza
    // richiedere davvero un tocco dell'utente in questa demo.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _checked[2] = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingHeader(
          title: 'La tua spesa, organizzata',
          subtitle: 'Segna quello che hai già preso, resta sempre dentro '
              'budget.',
        ),
        const SizedBox(height: 20),
        DelayedEntrance(
          child: DemoCard(
            child: Column(
              children: List.generate(demoShoppingList.length, (i) {
                final item = demoShoppingList[i];
                final done = _checked[i];
                return DelayedEntrance(
                  delay: Duration(milliseconds: i * 120),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: AppIcon(
                            HeroIcons.checkCircle,
                            key: ValueKey(done),
                            solid: done,
                            size: 20,
                            color: done
                                ? IconPalette.primary
                                : IconPalette.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: done
                                ? const Color(0xFF64748B)
                                : IconPalette.testo,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
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
        const SizedBox(height: 16),
        DelayedEntrance(
          delay: const Duration(milliseconds: 900),
          child: DemoCard(
            color: IconPalette.sfondoAlt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Budget', demoShoppingBudget, IconPalette.testo),
                _stat('Speso', demoShoppingSpeso, IconPalette.orange),
                _stat(
                  'Rimanente',
                  demoShoppingBudget - demoShoppingSpeso,
                  IconPalette.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          '€${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
