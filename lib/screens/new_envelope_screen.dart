import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/amount_input.dart';

class NewEnvelopeScreen extends StatefulWidget {
  /// Se valorizzata, lo schermo lavora in modalità modifica su questa
  /// busta esistente invece di crearne una nuova.
  final Envelope? envelope;

  const NewEnvelopeScreen({super.key, this.envelope});

  @override
  State<NewEnvelopeScreen> createState() => _NewEnvelopeScreenState();
}

class _NewEnvelopeScreenState extends State<NewEnvelopeScreen> {
  late final _nameController = TextEditingController(
    text: widget.envelope?.name,
  );
  late final _budgetController = TextEditingController(
    text: widget.envelope != null
        ? widget.envelope!.budget.toStringAsFixed(2)
        : '',
  );
  late String _selectedIcon = widget.envelope?.icon ?? '💰';
  final _service = FirestoreService();

  bool get _isEditing => widget.envelope != null;

  final icons = ['🏠', '🚗', '🛒', '🎉', '💊', '📱', '🎓', '💰'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica busta' : 'Nuova busta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome busta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: amountKeyboardType,
              decoration: const InputDecoration(
                labelText: 'Budget mensile (€) — opzionale',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Icona'),
            Wrap(
              spacing: 8,
              children: icons.map((icon) {
                final selected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: CircleAvatar(
                    backgroundColor: selected
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final budget = parseAmount(_budgetController.text) ?? 0;
                if (_nameController.text.isEmpty || budget < 0) return;
                if (_isEditing) {
                  await _service.updateEnvelope(
                    widget.envelope!.id,
                    name: _nameController.text,
                    category: _nameController.text,
                    budget: budget,
                    icon: _selectedIcon,
                    budgetDelta: budget - widget.envelope!.budget,
                  );
                } else {
                  await _service.addEnvelope(
                    Envelope(
                      id: '',
                      name: _nameController.text,
                      category: _nameController.text,
                      budget: budget,
                      balance: budget, // parte piena, si svuota con le spese
                      icon: _selectedIcon,
                    ),
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(_isEditing ? 'Salva modifiche' : 'Crea busta'),
            ),
          ],
        ),
      ),
    );
  }
}
