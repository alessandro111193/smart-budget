import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../models/app_user.dart';
import '../models/envelope.dart';
import '../models/recurring_expense.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import 'new_recurring_expense_screen.dart';
import 'premium_screen.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spese ricorrenti',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: StreamBuilder<List<RecurringExpense>>(
        stream: service.streamRecurringExpenses(),
        builder: (context, recSnapshot) {
          if (!recSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recurring = recSnapshot.data!;
          if (recurring.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessuna spesa ricorrente. Aggiungi le tue spese fisse '
                  '(es. Mutuo, Affitto) per ricevere un promemoria in Home '
                  'ogni mese, senza che vengano mai registrate da sole.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.neutral),
                ),
              ),
            );
          }
          return StreamBuilder<List<Envelope>>(
            stream: service.streamEnvelopes(),
            builder: (context, envSnapshot) {
              final envelopes = {
                for (final e in envSnapshot.data ?? <Envelope>[]) e.id: e,
              };
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recurring.length,
                itemBuilder: (context, i) {
                  final r = recurring[i];
                  final envelope = envelopes[r.envelopeId];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: const Color(0xFFF8FAFC),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const AppIcon(
                          HeroIcons.arrowPath,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(r.description),
                      subtitle: Text(
                        'Il giorno ${r.dayOfMonth} · ${envelope != null ? '${envelope.icon} ${envelope.name}' : 'busta eliminata'}'
                        '${r.active ? '' : ' · disattivata'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '€${r.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const AppIcon(HeroIcons.pencilSquare),
                            tooltip: 'Modifica',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NewRecurringExpenseScreen(recurring: r),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const AppIcon(
                              HeroIcons.trash,
                              color: AppColors.danger,
                            ),
                            tooltip: 'Elimina',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Elimina spesa ricorrente'),
                                  content: Text(
                                    'Vuoi davvero eliminare "${r.description}"? '
                                    'Le spese già registrate in passato restano '
                                    'invariate.',
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
                                await service.deleteRecurringExpense(r.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // Creare una nuova spesa ricorrente è Premium (trovato nell'audit
      // del 2026-09-03: prima era liberamente disponibile a chiunque,
      // contraddicendo il requisito esplicito) — gestire quelle già
      // esistenti (elenco sopra, modifica/elimina) resta libero.
      floatingActionButton: StreamBuilder<AppUser>(
        stream: service.streamUser(),
        builder: (context, userSnapshot) {
          final hasAi = userSnapshot.data?.hasAiAccess ?? false;
          return FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => hasAi
                    ? const NewRecurringExpenseScreen()
                    : PremiumScreen(),
              ),
            ),
            child: const AppIcon(HeroIcons.plus, color: Colors.white),
          );
        },
      ),
    );
  }
}
