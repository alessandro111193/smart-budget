import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../models/envelope.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/app_icons.dart';
import 'setup_scaffold.dart';

class _SuggestedEnvelope {
  final String name;
  final String emoji;
  final CategoryType category;

  /// Quota del budget suggerito sul totale dell'entrata inserita al
  /// passaggio precedente (somma delle quote = 1).
  final double incomeShare;

  const _SuggestedEnvelope(
    this.name,
    this.emoji,
    this.category,
    this.incomeShare,
  );
}

const _suggested = [
  _SuggestedEnvelope('Casa', '🏠', CategoryType.casa, 700 / 2400),
  _SuggestedEnvelope('Spesa', '🛒', CategoryType.spesa, 350 / 2400),
  _SuggestedEnvelope('Auto', '🚗', CategoryType.auto, 250 / 2400),
  _SuggestedEnvelope('Famiglia', '👨‍👩‍👧', CategoryType.famiglia, 300 / 2400),
  _SuggestedEnvelope('Svago', '🎉', CategoryType.svago, 200 / 2400),
  _SuggestedEnvelope('Risparmio', '💰', CategoryType.risparmio, 500 / 2400),
  _SuggestedEnvelope('Buffer', '🧯', CategoryType.altro, 100 / 2400),
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
    required this.onNext,
  });

  final double monthlyIncome;
  final VoidCallback onNext;

  @override
  State<SetupEnvelopesStep> createState() => _SetupEnvelopesStepState();
}

class _SetupEnvelopesStepState extends State<SetupEnvelopesStep> {
  final _service = FirestoreService();
  late final List<_EnvelopeDraft> _drafts = _suggested.map((s) {
    final base = widget.monthlyIncome > 0 ? widget.monthlyIncome : 2400;
    return _EnvelopeDraft(
      selected: true,
      name: s.name,
      budget: (base * s.incomeShare).roundToDouble(),
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
      final budget = double.tryParse(d.budgetController.text) ?? 0;
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
      subtitle: 'Ti propongo un punto di partenza: seleziona, modifica '
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
              keyboardType: TextInputType.number,
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
