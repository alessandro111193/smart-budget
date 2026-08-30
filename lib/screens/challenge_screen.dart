import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/challenge.dart';
import '../services/firestore_service.dart';

class ChallengeScreen extends StatelessWidget {
  ChallengeScreen({super.key});

  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showNewChallengeSheet(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Challenge>>(
        stream: _service.streamChallenges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final challenges = snapshot.data!;
          if (challenges.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna challenge ancora. Creane una col pulsante +',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: challenges
                .map((c) => _buildChallengeCard(context, c))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, Challenge c) {
    final isSaving = c.type == ChallengeType.saving;
    final progressColor = c.limitExceeded
        ? AppColors.danger
        : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSaving ? Icons.savings_outlined : Icons.speed_outlined,
                  size: 18,
                  color: progressColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (c.limitExceeded)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: c.percentComplete.clamp(0, 1),
              color: progressColor,
              backgroundColor: Colors.grey.shade200,
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              isSaving
                  ? '€${c.savedAmount.toStringAsFixed(0)} / €${c.targetAmount.toStringAsFixed(0)} risparmiati'
                  : '€${c.savedAmount.toStringAsFixed(0)} / €${c.targetAmount.toStringAsFixed(0)} del tetto di spesa',
            ),
            if (isSaving && c.monthlyQuota != null)
              Text(
                'Quota mensile consigliata: \u20ac${c.monthlyQuota!.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.neutral, fontSize: 12),
              ),
            if (c.limitExceeded)
              const Text(
                'Hai superato il tetto che ti eri dato.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showAddAmountDialog(context, c, isSaving),
                  child: Text(
                    isSaving ? '+ Aggiungi risparmio' : '+ Registra spesa',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAmountDialog(BuildContext context, Challenge c, bool isSaving) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSaving ? 'Aggiungi al risparmio' : 'Registra spesa'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '€ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                _service.addToChallenge(c.id, amount);
              }
              Navigator.pop(context);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showNewChallengeSheet(BuildContext context) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    ChallengeType selectedType = ChallengeType.saving;
    DateTime? deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nuova challenge',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<ChallengeType>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: ChallengeType.saving,
                        child: Text('Obiettivo di risparmio'),
                      ),
                      DropdownMenuItem(
                        value: ChallengeType.spendingLimit,
                        child: Text('Tetto di spesa'),
                      ),
                    ],
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nome challenge',
                    ),
                  ),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: selectedType == ChallengeType.saving
                          ? 'Obiettivo da raggiungere (\u20ac)'
                          : 'Tetto massimo di spesa (\u20ac)',
                    ),
                  ),
                  if (selectedType == ChallengeType.saving)
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => deadline = picked);
                      },
                      child: Text(
                        deadline == null
                            ? 'Scegli scadenza (opzionale)'
                            : 'Scadenza: ${deadline!.day}/${deadline!.month}/${deadline!.year}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final target =
                          double.tryParse(targetController.text) ?? 0;
                      if (titleController.text.isEmpty || target <= 0) return;
                      await _service.addChallenge(
                        Challenge(
                          id: '',
                          title: titleController.text,
                          type: selectedType,
                          targetAmount: target,
                          savedAmount: 0,
                          deadline: selectedType == ChallengeType.saving
                              ? deadline
                              : null,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Crea challenge'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
