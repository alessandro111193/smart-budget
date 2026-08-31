import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../services/family_service.dart';
import '../theme/app_theme.dart';

class NewFamilyEnvelopeScreen extends StatefulWidget {
  final String familyId;
  const NewFamilyEnvelopeScreen({super.key, required this.familyId});

  @override
  State<NewFamilyEnvelopeScreen> createState() =>
      _NewFamilyEnvelopeScreenState();
}

class _NewFamilyEnvelopeScreenState extends State<NewFamilyEnvelopeScreen> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  String _selectedIcon = '👨‍👩‍👧';
  final _service = FamilyService();

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
        title: const Text(
          'Nuova busta familiare',
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
              controller: _nameController,
              decoration: _fieldDecoration(labelText: 'Nome busta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
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
                  final budget = double.tryParse(_budgetController.text) ?? 0;
                  if (_nameController.text.isEmpty || budget <= 0) return;
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
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Crea busta familiare',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
