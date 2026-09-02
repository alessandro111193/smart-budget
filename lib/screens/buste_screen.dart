import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/envelope.dart';
import '../widgets/app_icons.dart';
import 'new_envelope_screen.dart';

class BusteScreen extends StatelessWidget {
  const BusteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Le tue buste')),
      body: StreamBuilder<List<Envelope>>(
        stream: service.streamEnvelopes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final envelopes = snapshot.data!;
          final totalBudget = service.totalBudget(envelopes);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Totale budget',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€${totalBudget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: envelopes.length,
                  itemBuilder: (context, i) {
                    final e = envelopes[i];
                    final color = AppColors
                        .envelopeColors[i % AppColors.envelopeColors.length];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      color: const Color(0xFFF8FAFC),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Text(
                            e.icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Text(e.name),
                        subtitle: Text(
                          e.budget == 0
                              ? 'Nessun budget impostato'
                              : 'Budget: €${e.budget.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '€${e.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const AppIcon(HeroIcons.pencilSquare),
                              tooltip: 'Modifica busta',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NewEnvelopeScreen(envelope: e),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const AppIcon(
                                HeroIcons.trash,
                                color: AppColors.danger,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Elimina busta'),
                                    content: Text(
                                      'Vuoi davvero eliminare la busta "${e.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Annulla'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Elimina',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await service.deleteEnvelope(e.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewEnvelopeScreen(),
                      ),
                    ),
                    icon: const AppIcon(HeroIcons.plus, color: Colors.white),
                    label: const Text('Nuova busta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
