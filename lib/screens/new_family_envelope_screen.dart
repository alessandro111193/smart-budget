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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova busta familiare')),
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Budget mensile (€)',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
              child: const Text('Crea busta familiare'),
            ),
          ],
        ),
      ),
    );
  }
}
