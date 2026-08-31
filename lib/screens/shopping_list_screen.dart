import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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

  _Suggestion({
    required this.name,
    required this.key,
    required this.category,
    required this.frequency,
    required this.lastBought,
    required this.dueRatio,
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
  final _addController = TextEditingController();

  static final _quantitySuffix = RegExp(r'\s*\(x\d+\)$', caseSensitive: false);

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  String _normalize(String raw) => raw.replaceAll(_quantitySuffix, '').trim();

  List<_Suggestion> _computeSuggestions(List<Expense> expenses) {
    final names = <String, String>{};
    final categories = <String, String>{};
    final dates = <String, List<DateTime>>{};

    for (final e in expenses) {
      final name = _normalize(e.description);
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      names[key] = name;
      categories[key] = e.category;
      (dates[key] ??= []).add(e.date);
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

      suggestions.add(_Suggestion(
        name: names[key]!,
        key: key,
        category: categories[key]!,
        frequency: purchaseDates.length,
        lastBought: purchaseDates.last,
        dueRatio: dueRatio,
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
        title: const Text('Lista della spesa'),
        actions: [
          IconButton(
            tooltip: 'Segna tutto da ricomprare',
            icon: const Icon(Icons.refresh),
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
            decoration: const InputDecoration(
              labelText: 'Aggiungi un articolo',
              isDense: true,
            ),
            onSubmitted: (_) => _addManualItem(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppColors.primary),
          onPressed: _addManualItem,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _manualItemTile(String name, bool checked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
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
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
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
}
