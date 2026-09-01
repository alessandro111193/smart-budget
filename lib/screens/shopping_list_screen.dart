import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';

/// Suggerimento generato dallo storico acquisti: nessuna chiamata AI, solo
/// analisi di frequenza sulle spese passate (disponibile anche su Free).
class _Suggestion {
  final String name;
  final String key;
  final String category;
  final int frequency;
  final DateTime lastBought;
  final double dueRatio;
  final double averagePrice;

  _Suggestion({
    required this.name,
    required this.key,
    required this.category,
    required this.frequency,
    required this.lastBought,
    required this.dueRatio,
    required this.averagePrice,
  });

  bool get isDue => dueRatio >= 0.85;
}

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _service = FirestoreService();
  final _aiService = AiService();
  final _addController = TextEditingController();
  final _budgetController = TextEditingController();

  bool _budgetLoading = false;
  ShoppingListSuggestion? _budgetSuggestion;
  String? _budgetError;

  static final _quantitySuffix = RegExp(r'\s*\(x\d+\)$', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    AnalyticsService.logShoppingListUsed();
  }

  @override
  void dispose() {
    _addController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String _normalize(String raw) => raw.replaceAll(_quantitySuffix, '').trim();

  List<_Suggestion> _computeSuggestions(List<Expense> expenses) {
    final names = <String, String>{};
    final categories = <String, String>{};
    final dates = <String, List<DateTime>>{};
    final prices = <String, List<double>>{};

    for (final e in expenses) {
      final name = _normalize(e.description);
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      names[key] = name;
      categories[key] = e.category;
      (dates[key] ??= []).add(e.date);
      (prices[key] ??= []).add(e.amount);
    }

    final suggestions = <_Suggestion>[];
    for (final key in dates.keys) {
      final purchaseDates = dates[key]!..sort();
      if (purchaseDates.length < 2) continue;

      final intervals = <int>[];
      for (var i = 1; i < purchaseDates.length; i++) {
        intervals.add(purchaseDates[i].difference(purchaseDates[i - 1]).inDays);
      }
      final avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;
      final daysSinceLast =
          DateTime.now().difference(purchaseDates.last).inDays;
      final dueRatio = avgInterval > 0 ? daysSinceLast / avgInterval : 0.0;
      final itemPrices = prices[key]!;
      final avgPrice =
          itemPrices.reduce((a, b) => a + b) / itemPrices.length;

      suggestions.add(_Suggestion(
        name: names[key]!,
        key: key,
        category: categories[key]!,
        frequency: purchaseDates.length,
        lastBought: purchaseDates.last,
        dueRatio: dueRatio,
        averagePrice: avgPrice,
      ));
    }
    suggestions.sort((a, b) => b.dueRatio.compareTo(a.dueRatio));
    return suggestions.take(25).toList();
  }

  Future<void> _addManualItem() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    _addController.clear();
    await _service.addManualShoppingItem(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lista della spesa',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        actions: [
          StreamBuilder<AppUser>(
            stream: _service.streamUser(),
            builder: (context, snapshot) {
              final hasAi = snapshot.data?.hasAiAccess ?? false;
              if (!hasAi) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Lista della spesa con budget (AI)',
                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                onPressed: _showBudgetDialog,
              );
            },
          ),
          IconButton(
            tooltip: 'Segna tutto da ricomprare',
            icon: const Icon(Icons.refresh, color: AppColors.ink),
            onPressed: () => _service.clearShoppingListChecks(),
          ),
        ],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _service.streamExpenses(),
        builder: (context, expSnapshot) {
          if (!expSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final suggestions = _computeSuggestions(expSnapshot.data!);

          return StreamBuilder<ShoppingListState>(
            stream: _service.streamShoppingListState(),
            builder: (context, stateSnapshot) {
              final checked = stateSnapshot.data?.checked.toSet() ?? {};
              final manualItems = stateSnapshot.data?.manualItems ?? [];

              final daRicomprare =
                  suggestions.where((s) => s.isDue).toList();
              final abituali =
                  suggestions.where((s) => !s.isDue).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _addRow(),
                  const SizedBox(height: 16),
                  _budgetSuggestionCard(),
                  if (manualItems.isNotEmpty) ...[
                    _sectionTitle('Aggiunti da te'),
                    ...manualItems.map(
                      (name) => _manualItemTile(name, checked.contains(name)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (daRicomprare.isNotEmpty) ...[
                    _sectionTitle('Probabilmente da ricomprare'),
                    ...daRicomprare.map(
                      (s) => _suggestionTile(s, checked.contains(s.key)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (abituali.isNotEmpty) ...[
                    _sectionTitle('Acquisti abituali'),
                    ...abituali.map(
                      (s) => _suggestionTile(s, checked.contains(s.key)),
                    ),
                  ],
                  if (manualItems.isEmpty && suggestions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'Continua a registrare le spese: qui vedrai i '
                          'prodotti che compri più spesso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.neutral),
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

  Widget _addRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _addController,
            decoration: InputDecoration(
              hintText: 'Aggiungi un articolo',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _addManualItem(),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary,
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addManualItem,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _manualItemTile(String name, bool checked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: CheckboxListTile(
        value: checked,
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          name,
          style: TextStyle(
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked ? AppColors.neutral : AppColors.ink,
          ),
        ),
        secondary: IconButton(
          icon: const Icon(Icons.close, size: 18, color: AppColors.neutral),
          onPressed: () => _service.removeManualShoppingItem(name),
        ),
        onChanged: (v) =>
            _service.setShoppingListItemChecked(name, v ?? false),
      ),
    );
  }

  Widget _suggestionTile(_Suggestion s, bool checked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: CheckboxListTile(
        value: checked,
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          s.name,
          style: TextStyle(
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked ? AppColors.neutral : AppColors.ink,
          ),
        ),
        subtitle: Text(
          '${s.category} · comprato ${s.frequency} volte · ultima volta '
          '${s.lastBought.day}/${s.lastBought.month}',
          style: const TextStyle(fontSize: 11),
        ),
        secondary: s.isDue
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Da comprare',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        onChanged: (v) =>
            _service.setShoppingListItemChecked(s.key, v ?? false),
      ),
    );
  }

  // --- Punto 10a del piano AI Premium: lista della spesa con budget ---

  void _showBudgetDialog() {
    _budgetController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lista della spesa con budget'),
        content: TextField(
          controller: _budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Budget disponibile (€)',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _requestShoppingListSuggestion();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Genera lista',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Riepilogo compatto dei prodotti abituali con il loro prezzo medio
  /// storico (solo Dart/Firestore, zero costo) da passare all'AI: mai
  /// prezzi inventati per questi prodotti, mai tutto lo storico.
  String _buildShoppingListSummary(List<_Suggestion> suggestions) {
    final top = suggestions.take(15).toList();
    if (top.isEmpty) return '';
    final lines = top
        .map(
          (s) => '${s.name}: prezzo medio storico '
              '€${s.averagePrice.toStringAsFixed(2)} (categoria '
              '${s.category})',
        )
        .join(', ');
    return 'Prodotti abituali dell\'utente: $lines.';
  }

  Future<void> _requestShoppingListSuggestion() async {
    final budget = double.tryParse(
      _budgetController.text.replaceAll(',', '.'),
    );
    if (budget == null || budget <= 0) {
      setState(() => _budgetError = 'Inserisci un budget valido.');
      return;
    }
    setState(() {
      _budgetLoading = true;
      _budgetError = null;
      _budgetSuggestion = null;
    });
    try {
      final expenses = await _service.streamExpenses().first;
      final suggestions = _computeSuggestions(expenses);
      final summary = _buildShoppingListSummary(suggestions);
      if (summary.isEmpty) {
        setState(() {
          _budgetLoading = false;
          _budgetError = 'Continua a registrare le spese: mi servono '
              'almeno alcuni acquisti abituali per proporti una lista.';
        });
        return;
      }
      final result = await _aiService.suggestShoppingList(
        budget: budget,
        summary: summary,
      );
      if (!mounted) return;
      setState(() {
        _budgetSuggestion = result;
        _budgetLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _budgetError = e.toString().replaceFirst('Exception: ', '');
        _budgetLoading = false;
      });
    }
  }

  Future<void> _addAllSuggestedItems() async {
    final suggestion = _budgetSuggestion;
    if (suggestion == null) return;
    for (final item in suggestion.items) {
      await _service.addManualShoppingItem(item.nome);
    }
    setState(() => _budgetSuggestion = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Articoli aggiunti alla lista della spesa.'),
        ),
      );
    }
  }

  Widget _budgetSuggestionCard() {
    final suggestion = _budgetSuggestion;
    if (suggestion == null && _budgetError == null && !_budgetLoading) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                child: Icon(Icons.smart_toy, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lista della spesa con budget',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (suggestion != null || _budgetError != null)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.neutral,
                  ),
                  onPressed: () => setState(() {
                    _budgetSuggestion = null;
                    _budgetError = null;
                  }),
                ),
            ],
          ),
          if (_budgetLoading) ...[
            const SizedBox(height: 8),
            const Text(
              'Sto preparando la lista...',
              style: TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
          ],
          if (_budgetError != null) ...[
            const SizedBox(height: 8),
            Text(
              _budgetError!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ],
          if (suggestion != null) ...[
            if (suggestion.motivazione.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                suggestion.motivazione,
                style: const TextStyle(fontSize: 12, color: AppColors.neutral),
              ),
            ],
            const SizedBox(height: 8),
            ...suggestion.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${item.nome}: €${item.prezzoStimato.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Totale stimato: €${suggestion.totaleStimato.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                onPressed: _addAllSuggestedItems,
                child: const Text(
                  'Aggiungi tutti alla lista',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
