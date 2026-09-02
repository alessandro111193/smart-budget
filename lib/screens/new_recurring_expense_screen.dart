import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../models/recurring_expense.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class NewRecurringExpenseScreen extends StatefulWidget {
  /// Se valorizzata, lo schermo lavora in modalità modifica su questa
  /// spesa ricorrente esistente invece di crearne una nuova.
  final RecurringExpense? recurring;

  const NewRecurringExpenseScreen({super.key, this.recurring});

  @override
  State<NewRecurringExpenseScreen> createState() =>
      _NewRecurringExpenseScreenState();
}

class _NewRecurringExpenseScreenState
    extends State<NewRecurringExpenseScreen> {
  late final _descriptionController = TextEditingController(
    text: widget.recurring?.description,
  );
  late final _amountController = TextEditingController(
    text: widget.recurring != null
        ? widget.recurring!.amount.toStringAsFixed(2)
        : '',
  );
  late String? _selectedEnvelopeId = widget.recurring?.envelopeId;
  late int _dayOfMonth = widget.recurring?.dayOfMonth ?? 1;
  bool _saving = false;
  final _service = FirestoreService();

  bool get _isEditing => widget.recurring != null;

  static InputDecoration _fieldDecoration({
    String? labelText,
    String? hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final description = _descriptionController.text.trim();
    if (amount <= 0 ||
        description.isEmpty ||
        _selectedEnvelopeId == null ||
        _selectedEnvelopeId == kGeneralEnvelopeSentinel) {
      return;
    }
    setState(() => _saving = true);
    if (_isEditing) {
      await _service.updateRecurringExpense(
        RecurringExpense(
          id: widget.recurring!.id,
          description: description,
          amount: amount,
          envelopeId: _selectedEnvelopeId!,
          dayOfMonth: _dayOfMonth,
          active: widget.recurring!.active,
          lastGeneratedMonthKey: widget.recurring!.lastGeneratedMonthKey,
        ),
      );
    } else {
      await _service.addRecurringExpense(
        RecurringExpense(
          id: '',
          description: description,
          amount: amount,
          envelopeId: _selectedEnvelopeId!,
          dayOfMonth: _dayOfMonth,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifica spesa ricorrente' : 'Nuova spesa ricorrente',
          style: const TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: _fieldDecoration(
                labelText: 'Descrizione',
                hintText: 'Es. Mutuo, Affitto, Palestra...',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(
                labelText: 'Importo',
                prefixText: '€ ',
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Envelope>>(
              stream: _service.streamEnvelopes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final envelopes = snapshot.data!
                    .where((e) => !e.isGeneral)
                    .toList();
                return DropdownButtonFormField<String>(
                  key: ValueKey(_selectedEnvelopeId),
                  decoration: _fieldDecoration(
                    labelText: 'Busta',
                    hintText: 'Scegli busta',
                  ),
                  initialValue: envelopes.any((e) => e.id == _selectedEnvelopeId)
                      ? _selectedEnvelopeId
                      : null,
                  isExpanded: true,
                  items: envelopes
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text('${e.icon} ${e.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedEnvelopeId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: _fieldDecoration(labelText: 'Giorno del mese'),
              initialValue: _dayOfMonth,
              isExpanded: true,
              items: List.generate(28, (i) => i + 1)
                  .map(
                    (day) => DropdownMenuItem(
                      value: day,
                      child: Text('Il giorno $day di ogni mese'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _dayOfMonth = value);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'A partire da quel giorno vedrai un promemoria in Home per '
              'confermare la registrazione — non viene mai registrata da sola.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _saving
                      ? 'Salvataggio...'
                      : (_isEditing ? 'Salva modifiche' : 'Crea spesa ricorrente'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
