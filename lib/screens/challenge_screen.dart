import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/challenge.dart';
import '../models/envelope.dart';
import '../services/firestore_service.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  static final _service = FirestoreService();

  static InputDecoration _fieldDecoration({String? labelText}) {
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
          'Challenge & Sinking Funds',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showNewChallengeSheet(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: _service.streamEnvelopes(),
        builder: (context, envSnapshot) {
          final envelopes = envSnapshot.data ?? [];

          return StreamBuilder<List<Challenge>>(
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
                    style: TextStyle(color: AppColors.neutral),
                  ),
                );
              }

              final sinkingFunds = challenges
                  .where((c) => c.envelopeId != null)
                  .toList();
              final genericChallenges = challenges
                  .where((c) => c.envelopeId == null)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (sinkingFunds.isNotEmpty) ...[
                    const Text(
                      'Sinking Funds (Buste per Obiettivi)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sinkingFunds.map(
                      (c) => _buildChallengeCard(context, c, envelopes),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (genericChallenges.isNotEmpty) ...[
                    const Text(
                      'Obiettivi Generici & Tetti di Spesa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...genericChallenges.map(
                      (c) => _buildChallengeCard(context, c, envelopes),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Challenge c,
    List<Envelope> envelopes,
  ) {
    final isSaving = c.type == ChallengeType.saving;
    final progressColor = c.limitExceeded
        ? AppColors.danger
        : AppColors.primary;

    Envelope? linkedEnvelope;
    if (c.envelopeId != null) {
      linkedEnvelope = envelopes.cast<Envelope?>().firstWhere(
        (e) => e?.id == c.envelopeId,
        orElse: () => null,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: progressColor.withOpacity(0.12),
                  child: Icon(
                    isSaving ? Icons.savings_outlined : Icons.speed_outlined,
                    size: 16,
                    color: progressColor,
                  ),
                ),
                const SizedBox(width: 10),
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
            if (linkedEnvelope != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    linkedEnvelope.icon,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Busta collegata: ${linkedEnvelope.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.percentComplete.clamp(0, 1),
                color: progressColor,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSaving
                  ? '€${c.savedAmount.toStringAsFixed(0)} / €${c.targetAmount.toStringAsFixed(0)} risparmiati'
                  : '€${c.savedAmount.toStringAsFixed(0)} / €${c.targetAmount.toStringAsFixed(0)} del tetto di spesa',
            ),
            if (isSaving && c.monthlyQuota != null)
              Text(
                'Quota mensile consigliata: €${c.monthlyQuota!.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.neutral, fontSize: 12),
              ),
            if (isSaving && c.isOnTrack != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (c.isOnTrack!
                          ? AppColors.primary
                          : AppColors.warning)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.isOnTrack!
                      ? 'In linea con il piano'
                      : 'Sei indietro rispetto al piano',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: c.isOnTrack!
                        ? AppColors.primary
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    isSaving ? '+ Aggiungi risparmio' : '+ Registra spesa',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(isSaving ? 'Aggiungi al risparmio' : 'Registra spesa'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: _fieldDecoration().copyWith(prefixText: '€ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Conferma',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
    String? selectedEnvelopeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<List<Envelope>>(
          stream: _service.streamEnvelopes(),
          builder: (context, envSnapshot) {
            final envelopes = envSnapshot.data ?? [];

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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ChallengeType>(
                        initialValue: selectedType,
                        isExpanded: true,
                        decoration: _fieldDecoration(),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: _fieldDecoration(
                          labelText: 'Nome challenge',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(
                          labelText: selectedType == ChallengeType.saving
                              ? 'Obiettivo da raggiungere (€)'
                              : 'Tetto massimo di spesa (€)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedEnvelopeId,
                        decoration: _fieldDecoration(
                          labelText: 'Collega a una busta (opzionale)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nessuna busta (Obiettivo generico)'),
                          ),
                          ...envelopes.map(
                            (e) => DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text('${e.icon} ${e.name}'),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => selectedEnvelopeId = val),
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
                            if (picked != null) {
                              setState(() => deadline = picked);
                            }
                          },
                          child: Text(
                            deadline == null
                                ? 'Scegli scadenza (opzionale)'
                                : 'Scadenza: ${deadline!.day}/${deadline!.month}/${deadline!.year}',
                          ),
                        ),
                      const SizedBox(height: 16),
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
                            final target =
                                double.tryParse(targetController.text) ?? 0;
                            if (titleController.text.isEmpty || target <= 0) {
                              return;
                            }
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
                                envelopeId: selectedEnvelopeId,
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text(
                            'Crea challenge',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
