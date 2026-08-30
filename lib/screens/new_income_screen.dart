import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/envelope.dart';
import '../services/firestore_service.dart';

class NewIncomeScreen extends StatefulWidget {
  const NewIncomeScreen({super.key});

  @override
  State<NewIncomeScreen> createState() => _NewIncomeScreenState();
}

class _NewIncomeScreenState extends State<NewIncomeScreen> {
  final _service = FirestoreService();
  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Categoria selezionata per l'entrata
  String _selectedCategory = 'Stipendio';
  final List<String> _categories = [
    'Stipendio',
    'Freelance',
    'Vendita',
    'Regalo',
    'Altro',
  ];

  final Map<String, TextEditingController> _allocationControllers = {};

  double get _totalIncome => double.tryParse(_totalController.text) ?? 0;

  double _totalAssigned() {
    return _allocationControllers.values.fold(
      0,
      (s, c) => s + (double.tryParse(c.text) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova entrata')),
      body: StreamBuilder<List<Envelope>>(
        stream: _service.streamEnvelopes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final envelopes = snapshot.data!;
          for (final e in envelopes) {
            _allocationControllers.putIfAbsent(
              e.id,
              () => TextEditingController(),
            );
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              final assigned = _totalAssigned();
              final remaining = _totalIncome - assigned;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Scelta Categoria
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setLocalState(() => _selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Campo Descrizione
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Descrizione (opzionale)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Campo Importo Totale
                        TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Importo totale entrata (€)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setLocalState(() {}),
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
                            color: remaining < 0
                                ? AppColors.danger
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
                                child: Text(
                                  '${env.icon} ${env.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _allocationControllers[env.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    prefixText: '€ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setLocalState(() {}),
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
                        onPressed: _totalIncome > 0
                            ? () async {
                                final allocations = <String, double>{};
                                _allocationControllers.forEach((id, c) {
                                  allocations[id] =
                                      double.tryParse(c.text) ?? 0;
                                });

                                final description = _descriptionController.text
                                    .trim();
                                final finalDesc = description.isEmpty
                                    ? _selectedCategory
                                    : description;

                                // Chiamata al servizio con la categoria inclusa
                                await _service.addIncome(
                                  description: finalDesc,
                                  amount: _totalIncome,
                                  category: _selectedCategory,
                                  allocations: allocations,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Entrata registrata e distribuita!',
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: const Text(
                          'Registra e distribuisci entrata',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
