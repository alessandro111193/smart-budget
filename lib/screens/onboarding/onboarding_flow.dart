import 'package:flutter/material.dart';

import '../../services/onboarding_service.dart';
import '../../theme/icon_palette.dart';
import 'demo/demo_page_ai.dart';
import 'demo/demo_page_analisi.dart';
import 'demo/demo_page_buste.dart';
import 'demo/demo_page_famiglia.dart';
import 'demo/demo_page_lista_spesa.dart';
import 'demo/demo_page_mini_home.dart';
import 'demo/demo_page_obiettivi.dart';
import 'demo/demo_page_premium.dart';
import 'demo/demo_page_scanner.dart';
import 'demo/demo_page_spese.dart';
import 'demo/demo_page_welcome.dart';

/// Mini demo interattiva mostrata una sola volta per dispositivo, prima
/// ancora del login: 11 schermate che FANNO VEDERE come funziona l'app
/// (dati statici, nessuna scrittura su Firestore) invece di limitarsi a
/// descriverla. Sostituisce il vecchio `OnboardingScreen`
/// (titolo+testo+icona+pulsante) — vedi CLAUDE.md per il confronto.
///
/// Al termine (ultima pagina o "Salta") chiama [onDone]: da lì in poi la
/// logica esistente in `_RootGate` decide se mostrare login o Home. La
/// demo stessa non richiede mai un account.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _index = 0;

  late final _pages = <Widget>[
    const DemoPageWelcome(),
    const DemoPageMiniHome(),
    const DemoPageBuste(),
    const DemoPageSpese(),
    const DemoPageScanner(),
    const DemoPageListaSpesa(),
    const DemoPageAnalisi(),
    const DemoPageObiettivi(),
    const DemoPageFamiglia(),
    const DemoPageAi(),
    const DemoPagePremium(),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.markOnboardingSeen();
    widget.onDone();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  String get _primaryLabel {
    if (_index == 0) return 'Scopri come funziona';
    if (_index == _pages.length - 1) return 'Inizia';
    return 'Avanti';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IconPalette.sfondoAlt,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_index > 0)
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: IconPalette.accent,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: IconPalette.accent,
                    ),
                    child: const Text('Salta'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: _pages
                    .map(
                      (p) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: p,
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? IconPalette.primary
                          : IconPalette.accent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IconPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    _primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
