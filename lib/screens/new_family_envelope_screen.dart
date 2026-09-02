import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../services/family_service.dart';
import '../theme/app_theme.dart';
import '../utils/amount_input.dart';

class NewFamilyEnvelopeScreen extends StatefulWidget {
  final String familyId;
  /// Se valorizzata, lo schermo lavora in modalità modifica su questa
  /// busta familiare esistente invece di crearne una nuova.
  final Envelope? envelope;

  const NewFamilyEnvelopeScreen({
    super.key,
    required this.familyId,
    this.envelope,
  });

  @override
  State<NewFamilyEnvelopeScreen> createState() =>
      _NewFamilyEnvelopeScreenState();
}

class _NewFamilyEnvelopeScreenState extends State<NewFamilyEnvelopeScreen> {
  late final _nameController = TextEditingController(
    text: widget.envelope?.name,
  );
  late final _budgetController = TextEditingController(
    text: widget.envelope != null
        ? widget.envelope!.budget.toStringAsFixed(2)
        : '',
  );
  late String _selectedIcon = widget.envelope?.icon ?? '👨‍👩‍👧';
  final _service = FamilyService();

  bool get _isEditing => widget.envelope != null;

  final icons = ['🏠', '🚗', '🛒', '🎉', '💊', '📱', '🎓', '👨‍👩‍👧'];

  static InputDecoration _fieldDecoration({required String labelText}) {
    return InputDecoration(
      labelText: labelText,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifica busta familiare' : 'Nuova busta familiare',
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
              controller: _nameController,
              decoration: _fieldDecoration(labelText: 'Nome busta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: amountKeyboardType,
              decoration: _fieldDecoration(labelText: 'Budget mensile (€)'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Icona',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: icons.map((icon) {
                final selected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: selected
                        ? AppColors.primary
                        : const Color(0xFFF8FAFC),
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
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
                onPressed: () async {
                  final budget = parseAmount(_budgetController.text) ?? 0;
                  if (_nameController.text.isEmpty || budget <= 0) return;
                  if (_isEditing) {
                    await _service.updateFamilyEnvelope(
                      widget.familyId,
                      widget.envelope!.id,
                      name: _nameController.text,
                      category: _nameController.text,
                      budget: budget,
                      icon: _selectedIcon,
                      budgetDelta: budget - widget.envelope!.budget,
                    );
                  } else {
                    await _service.addFamilyEnvelope(
                      widget.familyId,
                      Envelope(
                        id: '',
                        name: _nameController.text,
                        category: _nameController.text,
                        budget: budget,
                        balance: budget,
                        icon: _selectedIcon,
                      ),
                    );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  _isEditing ? 'Salva modifiche' : 'Crea busta familiare',
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
