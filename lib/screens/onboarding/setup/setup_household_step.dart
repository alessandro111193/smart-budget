import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import 'setup_scaffold.dart';

/// Passaggio del wizard reale, tra entrata e buste: quante persone
/// vivono nello stesso nucleo familiare. Non scrive nulla su Firestore
/// (è solo un moltiplicatore usato dal passaggio successivo per
/// proporzionare i budget suggeriti di alcune categorie — Fase E del
/// giro di correzioni post-audit, "stima automatica in base al nucleo
/// familiare": solo regole/statistiche, nessuna chiamata AI, coerente
/// con "Free non fa mai chiamate AI").
class SetupHouseholdStep extends StatefulWidget {
  const SetupHouseholdStep({super.key, required this.onNext});

  final void Function(int householdSize) onNext;

  @override
  State<SetupHouseholdStep> createState() => _SetupHouseholdStepState();
}

class _SetupHouseholdStepState extends State<SetupHouseholdStep> {
  int _size = 1;

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'In quante persone vivete insieme?',
      subtitle: 'Ti aiuta a proporti budget più realistici per la spesa e '
          'le altre voci che dipendono da quante persone siete in casa.',
      primaryLabel: 'Continua',
      onPrimary: () => widget.onNext(_size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const AppIcon(HeroIcons.minusCircle),
              color: _size > 1 ? IconPalette.primary : IconPalette.accent,
              onPressed: _size > 1 ? () => setState(() => _size--) : null,
            ),
            Column(
              children: [
                Text(
                  '$_size',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: IconPalette.testo,
                  ),
                ),
                Text(
                  _size == 1 ? 'persona' : 'persone',
                  style: const TextStyle(
                    fontSize: 13,
                    color: IconPalette.accent,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const AppIcon(HeroIcons.plusCircle),
              color: _size < 8 ? IconPalette.primary : IconPalette.accent,
              onPressed: _size < 8 ? () => setState(() => _size++) : null,
            ),
          ],
        ),
      ),
    );
  }
}
