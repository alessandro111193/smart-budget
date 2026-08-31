import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/envelope.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
import '../services/family_service.dart';

class NewFamilyExpenseScreen extends StatefulWidget {
  final String familyId;
  const NewFamilyExpenseScreen({super.key, required this.familyId});

  @override
  State<NewFamilyExpenseScreen> createState() => _NewFamilyExpenseScreenState();
}

class _NewFamilyExpenseScreenState extends State<NewFamilyExpenseScreen> {
  final _service = FamilyService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedEnvelopeId;
  String? _selectedMemberId;
  FamilyExpenseType _type = FamilyExpenseType.shared;
  final Map<String, TextEditingController> _splitControllers = {};

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova spesa familiare')),
      body: StreamBuilder<List<FamilyMember>>(
        stream: _service.streamMembers(widget.familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];
          for (final m in members) {
            _splitControllers.putIfAbsent(
              m.userId,
              () => TextEditingController(),
            );
          }

          return StreamBuilder<List<Envelope>>(
            stream: _service.streamFamilyEnvelopes(widget.familyId),
            builder: (context, envSnapshot) {
              final envelopes = envSnapshot.data ?? [];

              return StatefulBuilder(
                builder: (context, setLocal) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Importo (€)',
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButton<String>(
                        hint: const Text('Busta familiare'),
                        value: _selectedEnvelopeId,
                        isExpanded: true,
                        items: envelopes
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text('${e.icon} ${e.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setLocal(() => _selectedEnvelopeId = v),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tipo di spesa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<FamilyExpenseType>(
                        title: const Text(
                          'Condivisa (a carico di tutta la famiglia)',
                        ),
                        value: FamilyExpenseType.shared,
                        groupValue: _type,
                        onChanged: (v) => setLocal(() => _type = v!),
                      ),
                      RadioListTile<FamilyExpenseType>(
                        title: const Text(
                          'Personale (a carico di un solo membro)',
                        ),
                        value: FamilyExpenseType.personal,
                        groupValue: _type,
                        onChanged: (v) => setLocal(() => _type = v!),
                      ),
                      RadioListTile<FamilyExpenseType>(
                        title: const Text(
                          'Ripartita (quote diverse tra membri)',
                        ),
                        value: FamilyExpenseType.split,
                        groupValue: _type,
                        onChanged: (v) => setLocal(() => _type = v!),
                      ),
                      const SizedBox(height: 12),
                      if (_type == FamilyExpenseType.personal)
                        DropdownButton<String>(
                          hint: const Text('Di chi è la spesa?'),
                          value: _selectedMemberId,
                          isExpanded: true,
                          items: members
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.userId,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => _selectedMemberId = v),
                        ),
                      if (_type == FamilyExpenseType.split)
                        ..._splitFields(members, setLocal),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _canSave(members)
                            ? () => _save(context)
                            : null,
                        child: const Text('Registra spesa'),
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

  List<Widget> _splitFields(List<FamilyMember> members, StateSetter setLocal) {
    final assigned = _splitControllers.values.fold<double>(
      0,
      (s, c) => s + (double.tryParse(c.text) ?? 0),
    );
    final remaining = _amount - assigned;
    return [
      ...members.map(
        (m) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(m.name)),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _splitControllers[m.userId],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(prefixText: '€ '),
                  onChanged: (_) => setLocal(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
      Text(
        'Da assegnare: €${remaining.toStringAsFixed(2)}',
        style: TextStyle(
          color: remaining == 0 ? AppColors.primary : AppColors.warning,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }

  bool _canSave(List<FamilyMember> members) {
    if (_amount <= 0 || _selectedEnvelopeId == null) return false;
    if (_type == FamilyExpenseType.personal) return _selectedMemberId != null;
    if (_type == FamilyExpenseType.split) {
      final assigned = _splitControllers.values.fold<double>(
        0,
        (s, c) => s + (double.tryParse(c.text) ?? 0),
      );
      return assigned == _amount;
    }
    return true;
  }

  Future<void> _save(BuildContext context) async {
    Map<String, double>? split;
    if (_type == FamilyExpenseType.split) {
      split = {
        for (final entry in _splitControllers.entries)
          entry.key: double.tryParse(entry.value.text) ?? 0,
      };
    }
    await _service.addFamilyExpense(
      widget.familyId,
      FamilyExpense(
        id: '',
        amount: _amount,
        description: _descriptionController.text,
        envelopeId: _selectedEnvelopeId!,
        date: DateTime.now(),
        type: _type,
        memberId: _type == FamilyExpenseType.personal
            ? _selectedMemberId
            : null,
        splitAllocations: split,
      ),
    );
    if (context.mounted) Navigator.pop(context);
  }
}
