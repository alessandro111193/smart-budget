import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../models/envelope.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/icon_palette.dart';
import '../../../utils/amount_input.dart';
import '../../../widgets/app_icons.dart';
import 'setup_scaffold.dart';

class _SuggestedEnvelope {
  final String name;
  final String emoji;
  final CategoryType category;

  /// Quota del budget suggerito sul totale dell'entrata inserita al
  /// passaggio precedente (somma delle quote = 1 per una persona sola —
  /// vedi [householdFactorPerExtraPerson]).
  final double incomeShare;

  /// Quanto cresce il budget suggerito di questa categoria per ogni
  /// persona oltre la prima nel nucleo familiare (Fase E). 0 per le
  /// categorie che non dipendono in modo evidente da quante persone sono
  /// in casa (es. Auto: la rata/l'assicurazione non cambia con gli
  /// occupanti; Risparmio/Fondo imprevisti: obiettivi scelti dall'utente,
  /// non un consumo). Valori scelti come approssimazione semplice e
  /// dichiarata (non una vera scala di equivalenza OECD, che richiederebbe
  /// distinguere adulti/minori — dato non raccolto qui): Spesa scala quasi
  /// linearmente con le bocche da sfamare, Casa/Famiglia in modo più lieve
  /// (bollette/attività che aumentano ma non raddoppiano con più persone).
  final double householdFactorPerExtraPerson;

  const _SuggestedEnvelope(
    this.name,
    this.emoji,
    this.category,
    this.incomeShare, [
    this.householdFactorPerExtraPerson = 0,
  ]);
}

const _suggested = [
  _SuggestedEnvelope('Casa', '🏠', CategoryType.casa, 700 / 2400, 0.15),
  _SuggestedEnvelope('Spesa', '🛒', CategoryType.spesa, 350 / 2400, 0.5),
  _SuggestedEnvelope('Auto', '🚗', CategoryType.auto, 250 / 2400),
  _SuggestedEnvelope(
    'Famiglia',
    '👨‍👩‍👧',
    CategoryType.famiglia,
    300 / 2400,
    0.3,
  ),
  _SuggestedEnvelope('Svago', '🎉', CategoryType.svago, 200 / 2400),
  _SuggestedEnvelope('Risparmio', '💰', CategoryType.risparmio, 500 / 2400),
  _SuggestedEnvelope('Fondo imprevisti', '🧯', CategoryType.altro, 100 / 2400),
];

class _EnvelopeDraft {
  bool selected;
  final TextEditingController nameController;
  final TextEditingController budgetController;
  final String emoji;
  final CategoryType category;

  _EnvelopeDraft({
    required this.selected,
    required String name,
    required double budget,
    required this.emoji,
    required this.category,
  }) : nameController = TextEditingController(text: name),
       budgetController = TextEditingController(
         text: budget > 0 ? budget.toStringAsFixed(0) : '',
       );

  void dispose() {
    nameController.dispose();
    budgetController.dispose();
  }
}

/// Passaggio 3 del wizard reale: selezione/modifica delle buste
/// suggerite, più la possibilità di aggiungerne di personalizzate. Le
/// buste selezionate vengono create davvero con
/// `FirestoreService.addEnvelope` (stesso servizio di "Nuova busta").
class SetupEnvelopesStep extends StatefulWidget {
  const SetupEnvelopesStep({
    super.key,
    required this.monthlyIncome,
    this.householdSize = 1,
    required this.onNext,
  });

  final double monthlyIncome;

  /// Numero di persone nel nucleo familiare (Fase E), raccolto nel
  /// passaggio precedente del wizard — vedi [_SuggestedEnvelope.householdFactorPerExtraPerson].
  final int householdSize;
  final VoidCallback onNext;

  @override
  State<SetupEnvelopesStep> createState() => _SetupEnvelopesStepState();
}

class _SetupEnvelopesStepState extends State<SetupEnvelopesStep> {
  final _service = FirestoreService();
  late final List<_EnvelopeDraft> _drafts = _suggested.map((s) {
    final base = widget.monthlyIncome > 0 ? widget.monthlyIncome : 2400;
    final extraPeople = (widget.householdSize - 1).clamp(0, 7);
    final householdFactor =
        1 + s.householdFactorPerExtraPerson * extraPeople;
    return _EnvelopeDraft(
      selected: true,
      name: s.name,
      budget: (base * s.incomeShare * householdFactor).roundToDouble(),
      emoji: s.emoji,
      category: s.category,
    );
  }).toList();

  bool _saving = false;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addCustom() {
    setState(() {
      _drafts.add(
        _EnvelopeDraft(
          selected: true,
          name: '',
          budget: 0,
          emoji: '💳',
          category: CategoryType.altro,
        ),
      );
    });
  }

  bool get _canContinue =>
      _drafts.any((d) => d.selected && d.nameController.text.trim().isNotEmpty);

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final d in _drafts) {
      final name = d.nameController.text.trim();
      final budget = parseAmount(d.budgetController.text) ?? 0;
      if (!d.selected || name.isEmpty || budget <= 0) continue;
      await _service.addEnvelope(
        Envelope(
          id: '',
          name: name,
          category: name,
          budget: budget,
          balance: budget,
          icon: d.emoji,
        ),
      );
    }
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Come vuoi organizzare i tuoi soldi?',
      subtitle: widget.householdSize > 1
          ? 'Ti propongo un punto di partenza, con importi già adattati per '
                '${widget.householdSize} persone in casa: seleziona, '
                'modifica gli importi o aggiungine una tua.'
          : 'Ti propongo un punto di partenza: seleziona, modifica '
                'gli importi o aggiungine una tua.',
      loading: _saving,
      primaryEnabled: _canContinue,
      primaryLabel: 'Crea le mie buste',
      onPrimary: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._drafts.map(_envelopeRow),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addCustom,
            icon: const AppIcon(
              HeroIcons.plus,
              size: 18,
              color: IconPalette.primary,
            ),
            label: const Text('Aggiungi una busta personalizzata'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IconPalette.primary,
              side: const BorderSide(color: IconPalette.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _envelopeRow(_EnvelopeDraft d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.selected
              ? IconPalette.primary.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: d.selected,
            activeColor: IconPalette.primary,
            onChanged: (v) => setState(() => d.selected = v ?? false),
          ),
          CategoryIcon(type: d.category, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: d.nameController,
              enabled: d.selected,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nome busta',
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: IconPalette.testo,
              ),
            ),
          ),
          SizedBox(
            width: 78,
            child: TextField(
              controller: d.budgetController,
              enabled: d.selected,
              textAlign: TextAlign.right,
              keyboardType: amountKeyboardType,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: '€',
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: IconPalette.testo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
