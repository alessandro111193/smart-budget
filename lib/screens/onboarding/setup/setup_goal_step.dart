import 'package:flutter/material.dart';

import '../../../models/challenge.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/icon_palette.dart';

/// Passaggio 4 del wizard reale: obiettivo di risparmio opzionale,
/// salvato con `FirestoreService.addChallenge` (stesso servizio della
/// schermata Challenge/Obiettivi già esistente).
class SetupGoalStep extends StatefulWidget {
  const SetupGoalStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<SetupGoalStep> createState() => _SetupGoalStepState();
}

class _SetupGoalStepState extends State<SetupGoalStep> {
  final _service = FirestoreService();
  bool? _wantsGoal;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final name = _nameController.text.trim();
    if (_wantsGoal == true && name.isNotEmpty && amount > 0) {
      setState(() => _saving = true);
      await _service.addChallenge(
        Challenge(
          id: '',
          title: name,
          type: ChallengeType.saving,
          targetAmount: amount,
          savedAmount: 0,
          deadline: _deadline,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) widget.onNext();
  }

  static InputDecoration _decoration({String? hint, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IconPalette.sfondoAlt,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hai un obiettivo di risparmio?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: IconPalette.testo,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton('Sì', true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _choiceButton('Non ancora', false),
                  ),
                ],
              ),
              if (_wantsGoal == true) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: _decoration(hint: 'Es. Vacanza'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(prefix: '€ ', hint: 'Importo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(
                        const Duration(days: 180),
                      ),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    _deadline == null
                        ? 'Scegli una data (opzionale)'
                        : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IconPalette.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_wantsGoal != null)
                SizedBox(
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
                    onPressed: _saving ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continua',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceButton(String label, bool value) {
    final selected = _wantsGoal == value;
    return OutlinedButton(
      onPressed: () => setState(() => _wantsGoal = value),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? IconPalette.primary.withValues(alpha: 0.1)
            : Colors.white,
        foregroundColor:
            selected ? IconPalette.primary : IconPalette.testo,
        side: BorderSide(
          color: selected ? IconPalette.primary : const Color(0xFFE2E8F0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
