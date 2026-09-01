import 'package:flutter/material.dart';

import '../../../services/firestore_service.dart';
import '../../../theme/icon_palette.dart';
import 'setup_scaffold.dart';

/// Passaggio 2 del wizard reale: prima entrata mensile, salvata con
/// `FirestoreService.addIncome` (stesso servizio di "Nuova entrata").
/// Nessuna allocazione qui: le buste, con i loro budget, si creano nel
/// passaggio successivo.
class SetupIncomeStep extends StatefulWidget {
  const SetupIncomeStep({super.key, required this.onNext});

  /// Riceve l'importo inserito (0 se l'utente ha saltato), per
  /// proporzionare i budget suggeriti delle buste nel passaggio dopo.
  final void Function(double amount) onNext;

  @override
  State<SetupIncomeStep> createState() => _SetupIncomeStepState();
}

class _SetupIncomeStepState extends State<SetupIncomeStep> {
  final _controller = TextEditingController();
  final _service = FirestoreService();
  bool _saving = false;

  double get _amount => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_amount <= 0) {
      widget.onNext(0);
      return;
    }
    setState(() => _saving = true);
    await _service.addIncome(
      description: 'Entrata mensile',
      amount: _amount,
      category: 'Stipendio',
      allocations: const {},
    );
    if (mounted) widget.onNext(_amount);
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Quanto entra ogni mese?',
      subtitle: 'Ti aiuta a proporti buste con budget realistici — '
          'potrai comunque cambiarli.',
      loading: _saving,
      primaryLabel: 'Continua',
      onPrimary: _save,
      secondaryLabel: 'Salta',
      onSecondary: () => widget.onNext(0),
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: IconPalette.testo,
        ),
        decoration: InputDecoration(
          hintText: '0',
          prefixText: '€ ',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: IconPalette.primary),
          ),
        ),
      ),
    );
  }
}
