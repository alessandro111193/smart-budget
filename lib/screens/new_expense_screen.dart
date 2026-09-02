import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class NewExpenseScreen extends StatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  State<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedEnvelopeId;
  bool _saving = false;
  final _service = FirestoreService();

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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<String?> _createEnvelopeInline() async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Nuova busta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: _fieldDecoration(labelText: 'Nome busta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(
                labelText: 'Budget mensile (€) — opzionale',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: nameController.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Crea',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return null;
    final budget = double.tryParse(budgetController.text) ?? 0;
    return _service.addEnvelope(
      Envelope(
        id: '',
        name: nameController.text.trim(),
        category: nameController.text.trim(),
        budget: budget,
        balance: budget,
        icon: '💰',
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _selectedEnvelopeId == null) return;
    setState(() => _saving = true);
    var envelopeId = _selectedEnvelopeId!;
    if (envelopeId == kGeneralEnvelopeSentinel) {
      envelopeId = await _service.ensureGeneralEnvelope();
    }
    await _service.addExpense(
      Expense(
        id: '',
        amount: amount,
        category: _descriptionController.text,
        envelopeId: envelopeId,
        description: _descriptionController.text,
        date: DateTime.now(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuova spesa',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
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
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(
                labelText: 'Importo',
                prefixText: '€ ',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: _fieldDecoration(labelText: 'Descrizione'),
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
                final selectableIds = {
                  ...envelopes.map((e) => e.id),
                  kGeneralEnvelopeSentinel,
                };
                return DropdownButtonFormField<String>(
                  // Key legata al valore selezionato: DropdownButtonFormField
                  // usa `initialValue` in stile FormField (letto solo alla
                  // creazione dello stato interno) — senza questa key, la
                  // selezione impostata a livello di codice dopo "+ Nuova
                  // busta" (setState del genitore) non farebbe aggiornare
                  // visivamente la voce mostrata nel dropdown.
                  key: ValueKey(_selectedEnvelopeId),
                  decoration: _fieldDecoration(
                    labelText: 'Busta',
                    hintText: 'Scegli busta',
                  ),
                  initialValue: selectableIds.contains(_selectedEnvelopeId)
                      ? _selectedEnvelopeId
                      : null,
                  isExpanded: true,
                  items: [
                    ...envelopes.map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.icon} ${e.name}'),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: kGeneralEnvelopeSentinel,
                      child: Text('📦 Spese generali'),
                    ),
                    const DropdownMenuItem(
                      value: kNewEnvelopeSentinel,
                      child: Text(
                        '+ Nuova busta',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == kNewEnvelopeSentinel) {
                      final newId = await _createEnvelopeInline();
                      if (newId != null && mounted) {
                        setState(() => _selectedEnvelopeId = newId);
                      }
                      return;
                    }
                    setState(() => _selectedEnvelopeId = value);
                  },
                );
              },
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
                  _saving ? 'Salvataggio...' : 'Registra spesa',
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
