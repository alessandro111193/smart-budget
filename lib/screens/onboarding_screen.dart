import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/onboarding_service.dart';

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

const _pages = [
  _OnboardingPage(
    icon: Icons.account_balance_wallet,
    color: AppColors.primary,
    title: 'Benvenuto in Spesa Intelligente',
    body: 'La app di budget basata sul cash stuffing digitale: ogni '
        'entrata si divide subito tra le tue buste, così sai sempre '
        'cosa puoi davvero spendere.',
  ),
  _OnboardingPage(
    icon: Icons.folder_outlined,
    color: AppColors.secondary,
    title: 'Buste, spese e statistiche',
    body: 'Gratis, per sempre: crea le tue buste, registra le spese, '
        'segui le statistiche e ricevi avvisi automatici se rischi di '
        'sforare — nessuna chiamata AI, zero costi nascosti.',
  ),
  _OnboardingPage(
    icon: Icons.smart_toy_outlined,
    color: AppColors.accent,
    title: 'Un consulente AI al tuo fianco',
    body: 'Con Premium, l\'AI analizza le tue abitudini, scansiona gli '
        'scontrini, ti consiglia come distribuire le entrate e ti '
        'avvisa prima che i problemi arrivino.',
  ),
  _OnboardingPage(
    icon: Icons.family_restroom,
    color: AppColors.warning,
    title: 'Gestite il budget insieme',
    body: 'Invita la tua famiglia, condividete buste ed entrate, e '
        'tenete sotto controllo le spese di tutti senza mai perdere il '
        'quadro d\'insieme.',
  ),
];

/// Onboarding mostrato una sola volta per dispositivo, alla primissima
/// apertura dell'app (prima ancora del login). Skippabile in ogni momento.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neutral,
                  ),
                  child: const Text('Salta'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _pageContent(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? _pages[_index].color
                        : AppColors.neutral.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Inizia' : 'Avanti',
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

  Widget _pageContent(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}
