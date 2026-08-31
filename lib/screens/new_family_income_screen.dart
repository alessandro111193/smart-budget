import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/envelope.dart';
import '../models/family.dart';
import '../services/family_service.dart';

class NewFamilyIncomeScreen extends StatefulWidget {
  final String familyId;
  const NewFamilyIncomeScreen({super.key, required this.familyId});

  @override
  State<NewFamilyIncomeScreen> createState() => _NewFamilyIncomeScreenState();
}

class _NewFamilyIncomeScreenState extends State<NewFamilyIncomeScreen> {
  final _service = FamilyService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedMemberId; // null = entrata del nucleo
  final Map<String, TextEditingController> _allocationControllers = {};

  double get _totalIncome => double.tryParse(_amountController.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova entrata familiare')),
      body: StreamBuilder<List<FamilyMember>>(
        stream: _service.streamMembers(widget.familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];

          return StreamBuilder<List<Envelope>>(
            stream: _service.streamFamilyEnvelopes(widget.familyId),
            builder: (context, envSnapshot) {
              final envelopes = envSnapshot.data ?? [];
              for (final e in envelopes) {
                _allocationControllers.putIfAbsent(
                  e.id,
                  () => TextEditingController(),
                );
              }

              return StatefulBuilder(
                builder: (context, setLocal) {
                  final assigned = _allocationControllers.values.fold<double>(
                    0,
                    (s, c) => s + (double.tryParse(c.text) ?? 0),
                  );
                  final remaining = _totalIncome - assigned;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Importo totale (€)',
                              ),
                              onChanged: (_) => setLocal(() {}),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Descrizione',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButton<String?>(
                              hint: const Text(
                                'Entrata del nucleo o di un membro?',
                              ),
                              value: _selectedMemberId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Nucleo familiare'),
                                ),
                                ...members.map(
                                  (m) => DropdownMenuItem(
                                    value: m.userId,
                                    child: Text(m.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setLocal(() => _selectedMemberId = v),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Assegnato: €${assigned.toStringAsFixed(2)}'),
                            Text(
                              'Da assegnare: €${remaining.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: remaining == 0
                                    ? AppColors.primary
                                    : AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: envelopes.length,
                          itemBuilder: (context, i) {
                            final env = envelopes[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('${env.icon} ${env.name}'),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller:
                                          _allocationControllers[env.id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(
                                        prefixText: '€ ',
                                      ),
                                      onChanged: (_) => setLocal(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: remaining == 0 && assigned > 0
                                ? () async {
                                    final allocations = <String, double>{};
                                    _allocationControllers.forEach((id, c) {
                                      allocations[id] =
                                          double.tryParse(c.text) ?? 0;
                                    });
                                    await _service.addFamilyIncome(
                                      familyId: widget.familyId,
                                      amount: _totalIncome,
                                      description: _descriptionController.text,
                                      memberId: _selectedMemberId,
                                      allocations: allocations,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                : null,
                            child: const Text('Distribuisci entrata'),
                          ),
                        ),
                      ),
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
}
