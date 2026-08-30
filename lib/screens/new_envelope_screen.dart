import 'package:flutter/material.dart';

import '../models/envelope.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class NewEnvelopeScreen extends StatefulWidget {
  const NewEnvelopeScreen({super.key});

  @override
  State<NewEnvelopeScreen> createState() => _NewEnvelopeScreenState();
}

class _NewEnvelopeScreenState extends State<NewEnvelopeScreen> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  String _selectedIcon = '💰';
  final _service = FirestoreService();

  final icons = ['🏠', '🚗', '🛒', '🎉', '💊', '📱', '🎓', '💰'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova busta')),
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
              onPressed: () async {
                final budget = double.tryParse(_budgetController.text) ?? 0;
                if (_nameController.text.isEmpty || budget <= 0) return;
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
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Crea busta'),
            ),
          ],
        ),
      ),
    );
  }
}
