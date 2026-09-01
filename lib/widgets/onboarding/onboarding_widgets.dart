import 'package:flutter/material.dart';

import '../../theme/icon_palette.dart';
import '../app_icons.dart';

/// Componenti visivi condivisi dalla mini demo dell'onboarding. Non sono
/// gli stessi widget privati di `home_screen.dart` (la Home reale resta
/// esclusa da questa modifica, come richiesto) ma replicano
/// deliberatamente lo stesso linguaggio grafico (card arrotondate,
/// palette, gerarchia tipografica) così la demo sembra già parte
/// dell'app, non uno scenario a parte.

/// Titolo + sottotitolo in cima a una schermata della demo.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: IconPalette.testo,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card arrotondata con ombra leggera, stile coerente in tutta la demo.
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Riga compatta "icona categoria + nome + importo", per le buste demo e
/// per l'anteprima riepilogo nel wizard reale.
class DemoEnvelopeRow extends StatelessWidget {
  const DemoEnvelopeRow({
    super.key,
    required this.name,
    required this.amount,
    required this.category,
    this.dense = false,
  });

  final String name;
  final double amount;
  final CategoryType category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 8),
      child: Row(
        children: [
          CategoryIcon(type: category, size: dense ? 30 : 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: dense ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: IconPalette.testo,
              ),
            ),
          ),
          Text(
            '€${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: dense ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: IconPalette.testo,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card riepilogo disponibilità (stile analogo alla card della Home
/// reale, ma componente a sé per non toccare `home_screen.dart`).
class DemoBalanceCard extends StatelessWidget {
  const DemoBalanceCard({
    super.key,
    required this.disponibile,
    required this.entrate,
    required this.spese,
    this.risparmio,
  });

  final double disponibile;
  final double entrate;
  final double spese;

  /// Se null, calcolato come entrate - spese. Esplicito quando il
  /// "risparmio" mostrato è un concetto diverso (es. quota accantonata
  /// nella busta Risparmio) e non deve coincidere col disponibile.
  final double? risparmio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IconPalette.primary, IconPalette.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: IconPalette.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disponibile',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '€${disponibile.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statColumn('Entrate', entrate),
              _statColumn('Spese', spese),
              _statColumn(
                'Risparmio',
                risparmio ?? (entrate - spese).clamp(0, entrate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          '€${value.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Progress bar sottile arrotondata (budget/obiettivi), sempre dentro
/// ClipRRect come da Design System.
class DemoProgressBar extends StatelessWidget {
  const DemoProgressBar({
    super.key,
    required this.value,
    this.color = IconPalette.primary,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: const Color(0xFFE2E8F0),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
