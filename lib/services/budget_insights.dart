import '../models/envelope.dart';
import '../models/expense.dart';

enum BudgetAlertSeverity { warning, danger }

class BudgetAlert {
  final String message;
  final BudgetAlertSeverity severity;

  BudgetAlert(this.message, this.severity);
}

/// Avvisi di budget calcolati solo con regole/statistiche su dati già
/// caricati (nessuna chiamata AI): disponibili anche sul piano Free, come
/// da CLAUDE.md ("Free non fa mai chiamate AI").
class BudgetInsights {
  static const double _highUsageThreshold = 0.85;

  /// Sotto questa soglia di giorni trascorsi nel mese non proiettiamo il
  /// ritmo di spesa: con 1 solo giorno di dati la proiezione sarebbe troppo
  /// rumorosa per essere utile.
  static const int _minDaysForProjection = 2;

  static List<BudgetAlert> compute({
    required List<Envelope> envelopes,
    required List<Expense> expenses,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final daysElapsed = today.day;
    final daysRemaining = daysInMonth - daysElapsed;
    final canProject = daysElapsed >= _minDaysForProjection && daysRemaining > 0;

    final monthExpenses = expenses.where(
      (e) => e.date.year == today.year && e.date.month == today.month,
    );

    final alerts = <BudgetAlert>[];

    for (final env in envelopes) {
      if (env.budget <= 0) continue;

      if (env.balance <= 0) {
        alerts.add(BudgetAlert(
          'Hai esaurito la busta "${env.name}".',
          BudgetAlertSeverity.danger,
        ));
        continue;
      }

      if (env.percentUsed >= _highUsageThreshold) {
        alerts.add(BudgetAlert(
          'Hai già utilizzato il ${(env.percentUsed * 100).round()}% '
          'del budget "${env.name}".',
          BudgetAlertSeverity.warning,
        ));
      }

      if (canProject) {
        final spentThisMonth = monthExpenses
            .where((e) => e.envelopeId == env.id)
            .fold<double>(0, (s, e) => s + e.amount);
        if (spentThisMonth > 0) {
          final dailyRate = spentThisMonth / daysElapsed;
          final projectedFurtherSpend = dailyRate * daysRemaining;
          if (projectedFurtherSpend > env.balance) {
            // Giorno stimato di esaurimento, solo se cade entro questo
            // mese — oltre non è un dato utile da mostrare con precisione
            // (l'andamento di oggi potrebbe non valere per settimane).
            final daysUntilEmpty = (env.balance / dailyRate).ceil();
            final exhaustionDay = daysElapsed + daysUntilEmpty;
            final dateText = exhaustionDay <= daysInMonth
                ? 'intorno al $exhaustionDay del mese'
                : 'prima della fine del mese';
            alerts.add(BudgetAlert(
              'La busta "${env.name}" viene utilizzata a un ritmo di circa '
              '€${dailyRate.toStringAsFixed(0)} al giorno: con questo '
              'andamento potrebbe esaurirsi $dateText.',
              BudgetAlertSeverity.warning,
            ));
          }
        }
      }
    }

    if (canProject) {
      final totalAvailable = envelopes.fold<double>(0, (s, e) => s + e.balance);
      final totalSpentThisMonth =
          monthExpenses.fold<double>(0, (s, e) => s + e.amount);
      if (totalSpentThisMonth > 0 && totalAvailable > 0) {
        final dailyRate = totalSpentThisMonth / daysElapsed;
        final projected =
            (totalAvailable - dailyRate * daysRemaining).clamp(0, totalAvailable);
        if (projected < totalAvailable * 0.3) {
          alerts.add(BudgetAlert(
            'Questo mese hai ancora €${totalAvailable.toStringAsFixed(0)} '
            'disponibili, ma continuando con questo ritmo di spesa '
            'potresti arrivare a fine mese con circa '
            '€${projected.toStringAsFixed(0)}.',
            BudgetAlertSeverity.warning,
          ));
        }
      }
    }

    alerts.sort((a, b) {
      if (a.severity == b.severity) return 0;
      return a.severity == BudgetAlertSeverity.danger ? -1 : 1;
    });

    return alerts;
  }
}
