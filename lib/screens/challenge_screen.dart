import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/challenge.dart';
import '../models/envelope.dart';
import '../services/firestore_service.dart';
import '../widgets/app_icons.dart';

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
        child: const AppIcon(HeroIcons.plus, color: Colors.white),
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

    // Sinking fund di risparmio collegato a una busta: il saldo reale
    // della busta è l'unica fonte di verità per il progresso, non il
    // contatore savedAmount della challenge (che per questi casi non viene
    // più aggiornato manualmente — vedi il bottone più sotto).
    final isLinkedSinkingFund = isSaving && linkedEnvelope != null;
    final effective = isLinkedSinkingFund
        ? c.copyWithSavedAmount(linkedEnvelope.balance)
        : c;

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
                  child: AppIcon(
                    isSaving ? HeroIcons.banknotes : HeroIcons.scale,
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
                  const AppIcon(
                    HeroIcons.exclamationTriangle,
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
                value: effective.percentComplete.clamp(0, 1),
                color: progressColor,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSaving
                  ? '€${effective.savedAmount.toStringAsFixed(0)} / €${effective.targetAmount.toStringAsFixed(0)} risparmiati'
                  : '€${effective.savedAmount.toStringAsFixed(0)} / €${effective.targetAmount.toStringAsFixed(0)} del tetto di spesa',
            ),
            if (isSaving && effective.monthlyQuota != null)
              Text(
                'Quota mensile consigliata: €${effective.monthlyQuota!.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.neutral, fontSize: 12),
              ),
            if (isSaving && effective.isOnTrack != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (effective.isOnTrack!
                          ? AppColors.primary
                          : AppColors.warning)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  effective.isOnTrack!
                      ? 'In linea con il piano'
                      : 'Sei indietro rispetto al piano',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: effective.isOnTrack!
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
            if (isLinkedSinkingFund)
              const Text(
                'Il saldo si aggiorna quando distribuisci un\'entrata verso '
                'questa busta, dalla schermata "Nuova entrata".',
                style: TextStyle(fontSize: 11, color: AppColors.neutral),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        _showAddAmountDialog(context, c, isSaving),
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
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          selectedType = ChallengeType.saving;
                          titleController.text = 'Sfida delle 52 settimane';
                          targetController.text = '1378';
                          deadline = DateTime.now().add(
                            const Duration(days: 364),
                          );
                        }),
                        icon: const AppIcon(
                          HeroIcons.fire,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        label: const Text(
                          'Usa il template: Sfida delle 52 settimane',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Metti da parte €1 la 1ª settimana, €2 la 2ª... '
                          'fino a €52 la 52ª: €1.378 in un anno. Puoi comunque '
                          'modificare titolo, obiettivo e scadenza qui sotto.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
