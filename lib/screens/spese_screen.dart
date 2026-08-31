import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../models/envelope.dart';
import 'new_expense_screen.dart';

class SpeseScreen extends StatefulWidget {
  const SpeseScreen({super.key});

  @override
  State<SpeseScreen> createState() => _SpeseScreenState();
}

class _SpeseScreenState extends State<SpeseScreen> {
  final _service = FirestoreService();
  String _selectedFilter = 'Tutte';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spese')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewExpenseScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: _service.streamEnvelopes(),
        builder: (context, envSnapshot) {
          final envelopes = envSnapshot.data ?? [];
          final envelopeById = {for (final e in envelopes) e.id: e};

          return StreamBuilder<List<Expense>>(
            stream: _service.streamExpenses(),
            builder: (context, expSnapshot) {
              if (!expSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var expenses = expSnapshot.data!.toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (_selectedFilter != 'Tutte') {
                expenses = expenses
                    .where(
                      (e) =>
                          envelopeById[e.envelopeId]?.name == _selectedFilter,
                    )
                    .toList();
              }

              final filters = ['Tutte', ...envelopes.map((e) => e.name)];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: filters.map((f) {
                          final selected = f == _selectedFilter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : AppColors.ink,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: expenses.isEmpty
                        ? const Center(
                            child: Text('Nessuna spesa in questa categoria'),
                          )
                        : _groupedList(expenses, envelopeById),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _groupedList(
    List<Expense> expenses,
    Map<String, Envelope> envelopeById,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<Expense>>{};
    for (final e in expenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      String label;
      if (day == today) {
        label = 'Oggi';
      } else if (day == yesterday) {
        label = 'Ieri';
      } else {
        label = '${day.day}/${day.month}/${day.year}';
      }
      groups.putIfAbsent(label, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: groups.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral,
              ),
            ),
          ),
          ...entry.value.map((e) {
            final env = envelopeById[e.envelopeId];
            final index = env == null
                ? 0
                : env.id.hashCode.abs() % AppColors.envelopeColors.length;
            final color = AppColors.envelopeColors[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: const Color(0xFFF8FAFC),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    env?.icon ?? '💸',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                title: Text(
                  e.description.isEmpty ? (env?.name ?? '') : e.description,
                ),
                subtitle: Text(env?.name ?? ''),
                trailing: Text(
                  '- €${e.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ),
            );
          }),
        ];
      }).toList(),
    );
  }
}
