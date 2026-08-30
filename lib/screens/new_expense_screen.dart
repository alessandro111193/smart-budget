import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

class NewExpenseScreen extends StatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  State<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedEnvelopeId;
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova spesa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Importo (€)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrizione'),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Envelope>>(
              stream: _service.streamEnvelopes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final envelopes = snapshot.data!;
                return DropdownButton<String>(
                  hint: const Text('Scegli busta'),
                  value: _selectedEnvelopeId,
                  isExpanded: true,
                  items: envelopes
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text('${e.icon} ${e.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedEnvelopeId = value),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(_amountController.text) ?? 0;
                if (amount <= 0 || _selectedEnvelopeId == null) return;
                await _service.addExpense(
                  Expense(
                    id: '',
                    amount: amount,
                    category: _descriptionController.text,
                    envelopeId: _selectedEnvelopeId!,
                    description: _descriptionController.text,
                    date: DateTime.now(),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Registra spesa'),
            ),
          ],
        ),
      ),
    );
  }
}
