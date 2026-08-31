import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
import '../models/envelope.dart';
import '../services/family_service.dart';
import 'new_family_envelope_screen.dart';
import 'new_family_income_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final String familyId;
  const FamilyDashboardScreen({super.key, required this.familyId});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final _service = FamilyService();
  String _selectedScope = 'Famiglia'; // "Famiglia" oppure userId di un membro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard Famiglia',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: StreamBuilder<List<FamilyMember>>(
        stream: _service.streamMembers(widget.familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];

          return StreamBuilder<List<FamilyExpense>>(
            stream: _service.streamFamilyExpenses(widget.familyId),
            builder: (context, expSnapshot) {
              final expenses = expSnapshot.data ?? [];

              return StreamBuilder<List<Envelope>>(
                stream: _service.streamFamilyEnvelopes(widget.familyId),
                builder: (context, envSnapshot) {
                  final envelopes = envSnapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _scopeSelector(members),
                      const SizedBox(height: 16),
                      _totalsCard(expenses, members),
                      const SizedBox(height: 16),
                      const Text(
                        'Buste condivise',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NewFamilyEnvelopeScreen(
                                    familyId: widget.familyId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Nuova busta'),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NewFamilyIncomeScreen(
                                    familyId: widget.familyId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add_card),
                              label: const Text('Nuova entrata'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (envelopes.isEmpty)
                        const Text(
                          'Nessuna busta familiare ancora creata.',
                          style: TextStyle(color: AppColors.neutral),
                        ),
                      ...envelopes.map((e) => _envelopeTile(e)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _scopeSelector(List<FamilyMember> members) {
    final chips = ['Famiglia', ...members.map((m) => m.userId)];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips.map((c) {
          final label = c == 'Famiglia'
              ? 'Famiglia'
              : members.firstWhere((m) => m.userId == c).name;
          final selected = c == _selectedScope;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _selectedScope = c),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _totalsCard(List<FamilyExpense> expenses, List<FamilyMember> members) {
    final isFamily = _selectedScope == 'Famiglia';
    final total = isFamily
        ? _service.familyTotalExpenses(expenses)
        : _service.memberExpenseTotal(expenses, _selectedScope, members.length);

    final sharedQuota = !isFamily
        ? expenses
              .where((e) => e.type == FamilyExpenseType.shared)
              .fold<double>(
                0,
                (s, e) => s + e.quotaFor(_selectedScope, members.length),
              )
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFamily ? 'Spese totali famiglia' : 'Le tue spese (quota)',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '€${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sharedQuota != null) ...[
            const SizedBox(height: 8),
            Text(
              'di cui quota condivisa: €${sharedQuota.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _envelopeTile(Envelope e) {
    final index = e.id.hashCode % AppColors.envelopeColors.length;
    final color = AppColors.envelopeColors[index.abs()];
    final percent = e.budget == 0 ? 0.0 : (e.budget - e.balance) / e.budget;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(e.icon, style: const TextStyle(fontSize: 18)),
        ),
        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              color: color,
              backgroundColor: Colors.grey.shade200,
              minHeight: 5,
            ),
          ),
        ),
        trailing: Text(
          '€${e.balance.toStringAsFixed(0)} / €${e.budget.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
