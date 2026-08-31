import '../models/expense.dart';

/// Calcola, solo con regole/statistiche su spese già caricate (nessuna
/// chiamata AI), le medie mensili per categoria e le variazioni recenti
/// significative — l'input "reale" che poi la Cloud Function
/// generateAiInsight(kind: "habit_analysis") userà per scrivere una
/// narrazione, senza mai dover inventare o ricalcolare numeri.
class HabitInsights {
  static const int _monthsBack = 6;
  static const double _significantChangePercent = 20;

  /// Restituisce una stringa vuota se non c'è ancora storico sufficiente
  /// (meno di due mesi completi con spese) per un'analisi affidabile: in
  /// quel caso il chiamante non deve invocare l'AI.
  static String buildSummary(List<Expense> expenses, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfThisMonth = DateTime(today.year, today.month, 1);

    // Solo mesi completi (esclude il mese in corso, ancora parziale),
    // fino a _monthsBack indietro.
    final monthBuckets = <String, Map<String, double>>{};
    for (final e in expenses) {
      if (!e.date.isBefore(startOfThisMonth)) continue;
      final monthsAgo = (startOfThisMonth.year - e.date.year) * 12 +
          (startOfThisMonth.month - e.date.month);
      if (monthsAgo > _monthsBack) continue;
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      final byCategory = monthBuckets.putIfAbsent(key, () => {});
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    if (monthBuckets.length < 2) return '';

    final sortedMonths = monthBuckets.keys.toList()..sort();
    final categories = <String>{};
    for (final byCategory in monthBuckets.values) {
      categories.addAll(byCategory.keys);
    }

    final buffer = StringBuffer();

    final averageLines = <String>[];
    for (final category in categories) {
      final totals =
          sortedMonths.map((m) => monthBuckets[m]![category] ?? 0).toList();
      final monthsWithSpending = totals.where((t) => t > 0).length;
      if (monthsWithSpending < 2) continue;
      final average = totals.reduce((a, b) => a + b) / totals.length;
      averageLines.add('$category: media €${average.toStringAsFixed(0)}/mese');
    }
    if (averageLines.isEmpty) return '';
    buffer.writeln(
      'Media mensile per categoria negli ultimi ${sortedMonths.length} '
      'mesi: ${averageLines.join(', ')}.',
    );

    // Ultimo mese completo vs media dei mesi precedenti, per categoria.
    final lastMonthKey = sortedMonths.last;
    final priorMonths = sortedMonths.sublist(0, sortedMonths.length - 1);
    if (priorMonths.isNotEmpty) {
      final trendLines = <String>[];
      for (final category in categories) {
        final lastValue = monthBuckets[lastMonthKey]![category] ?? 0;
        final priorValues =
            priorMonths.map((m) => monthBuckets[m]![category] ?? 0).toList();
        final priorAverage =
            priorValues.reduce((a, b) => a + b) / priorValues.length;
        if (priorAverage <= 0 || lastValue <= 0) continue;
        final change = ((lastValue - priorAverage) / priorAverage) * 100;
        if (change.abs() < _significantChangePercent) continue;
        trendLines.add(
          '$category ${change >= 0 ? 'aumentata' : 'diminuita'} del '
          '${change.abs().toStringAsFixed(0)}% nell\'ultimo mese rispetto '
          'alla media precedente',
        );
      }
      if (trendLines.isNotEmpty) {
        buffer.writeln('Variazioni recenti: ${trendLines.join(', ')}.');
      }
    }

    return buffer.toString().trim();
  }
}
