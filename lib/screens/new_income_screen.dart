import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../models/envelope.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/habit_insights.dart';
import '../widgets/app_icons.dart';

class NewIncomeScreen extends StatefulWidget {
  const NewIncomeScreen({super.key});

  @override
  State<NewIncomeScreen> createState() => _NewIncomeScreenState();
}

class _NewIncomeScreenState extends State<NewIncomeScreen> {
  final _service = FirestoreService();
  final _aiService = AiService();
  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _aiLoading = false;
  IncomeDistributionSuggestion? _aiSuggestion;
  String? _aiError;

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

  static InputDecoration _fieldDecoration({
    String? labelText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixText: prefixText,
      isDense: true,
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
          'Nuova entrata',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
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
                          initialValue: _selectedCategory,
                          decoration: _fieldDecoration(labelText: 'Categoria'),
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
                          decoration: _fieldDecoration(
                            labelText: 'Descrizione (opzionale)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Campo Importo Totale
                        TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(
                            labelText: 'Importo totale entrata (€)',
                          ),
                          onChanged: (_) => setLocalState(() {}),
                        ),
                      ],
                    ),
                  ),
                  if (_totalIncome > 0 && envelopes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _aiSuggestionSection(envelopes, setLocalState),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                  ),
                  const SizedBox(height: 12),
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
                                width: 120,
                                child: TextField(
                                  controller: _allocationControllers[env.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.right,
                                  decoration: _fieldDecoration(
                                    prefixText: '€ ',
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
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
                          style: TextStyle(fontWeight: FontWeight.bold),
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

  /// Sezione "Consiglio AI per la distribuzione" (punti 2+6 del piano AI
  /// Premium). Visibile solo a Premium/Trial. Non applica mai nulla da
  /// sola: mostra un bottone "Applica distribuzione" che precompila i
  /// campi di allocazione già esistenti, lasciando comunque all'utente il
  /// salvataggio finale con "Registra e distribuisci entrata".
  Widget _aiSuggestionSection(
    List<Envelope> envelopes,
    StateSetter setLocalState,
  ) {
    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, snapshot) {
        final hasAi = snapshot.data?.hasAiAccess ?? false;
        if (!hasAi) return const SizedBox.shrink();

        final suggestion = _aiSuggestion;
        if (suggestion != null) {
          final shownEnvelopes = envelopes
              .where((e) => (suggestion.allocations[e.id] ?? 0) > 0)
              .toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      child: AppIcon(
                        HeroIcons.sparkles,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ti consiglio questa distribuzione',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(
                        HeroIcons.xMark,
                        size: 18,
                        color: AppColors.neutral,
                      ),
                      onPressed: () =>
                          setLocalState(() => _aiSuggestion = null),
                    ),
                  ],
                ),
                if (suggestion.motivazione.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    suggestion.motivazione,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ...shownEnvelopes.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${e.icon} ${e.name}: €'
                      '${suggestion.allocations[e.id]!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _applySuggestion(setLocalState),
                    child: const Text(
                      'Applica distribuzione',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _aiLoading
                      ? null
                      : () => _requestAiSuggestion(envelopes, setLocalState),
                  icon: _aiLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const AppIcon(
                          HeroIcons.sparkles,
                          size: 18,
                          color: AppColors.primary,
                        ),
                  label: Text(
                    _aiLoading
                        ? 'Sto pensando...'
                        : 'Consiglio AI per la distribuzione',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_aiError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _aiError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _buildAllocationSummary(List<Envelope> envelopes) async {
    final envelopeLines = envelopes
        .map((e) {
          final pct = (e.percentUsed * 100).round();
          return '${e.name} (budget €${e.budget.toStringAsFixed(0)}, saldo '
              'attuale €${e.balance.toStringAsFixed(0)}, usata al $pct%)';
        })
        .join(', ');

    final buffer = StringBuffer('Buste attuali: $envelopeLines.');

    final challenges = await _service.streamChallenges().first;
    final goals = challenges.where(
      (c) =>
          c.type == ChallengeType.saving &&
          c.percentComplete < 1 &&
          c.monthlyQuota != null,
    );
    if (goals.isNotEmpty) {
      final goalLines = goals
          .map(
            (g) => '"${g.title}" quota mensile consigliata '
                '€${g.monthlyQuota!.toStringAsFixed(2)}',
          )
          .join(', ');
      buffer.write(' Obiettivi di risparmio attivi: $goalLines.');
    }

    // Storico spese: stesso riepilogo (medie per categoria + variazioni
    // recenti) già usato per la chat e per l'analisi abitudini, così l'AI
    // sa anche cosa aspettarsi di dover coprire con le buste, non solo il
    // loro stato attuale.
    final expenses = await _service.streamExpenses().first;
    final habitSummary = HabitInsights.buildSummary(expenses);
    if (habitSummary.isNotEmpty) {
      buffer.write(' Storico spese: $habitSummary');
    }

    // Storico entrate: quante e di che importo medio sono state le entrate
    // recenti, per capire se questa è un'entrata regolare o straordinaria.
    final incomes = await _service.streamIncomes().first;
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    final recentIncomes = incomes
        .where((i) => i.date.isAfter(sixMonthsAgo))
        .toList();
    if (recentIncomes.isNotEmpty) {
      final avgIncome =
          recentIncomes.fold<double>(0, (s, i) => s + i.amount) /
          recentIncomes.length;
      buffer.write(
        ' Storico entrate: ${recentIncomes.length} entrate negli ultimi 6 '
        'mesi, importo medio €${avgIncome.toStringAsFixed(0)}.',
      );
    }

    return buffer.toString();
  }

  Future<void> _requestAiSuggestion(
    List<Envelope> envelopes,
    StateSetter setLocalState,
  ) async {
    setLocalState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final summary = await _buildAllocationSummary(envelopes);
      final suggestion = await _aiService.suggestIncomeDistribution(
        incomeAmount: _totalIncome,
        envelopes: envelopes.map((e) => (id: e.id, name: e.name)).toList(),
        summary: summary,
      );
      if (!mounted) return;
      setLocalState(() {
        _aiSuggestion = suggestion;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setLocalState(() {
        _aiError = e.toString().replaceFirst('Exception: ', '');
        _aiLoading = false;
      });
    }
  }

  void _applySuggestion(StateSetter setLocalState) {
    final suggestion = _aiSuggestion;
    if (suggestion == null) return;
    setLocalState(() {
      suggestion.allocations.forEach((envelopeId, amount) {
        _allocationControllers[envelopeId]?.text = amount.toStringAsFixed(2);
      });
      _aiSuggestion = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Distribuzione applicata: controlla e correggi se serve prima '
          'di salvare.',
        ),
      ),
    );
  }
}
