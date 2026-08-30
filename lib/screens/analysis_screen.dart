import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../models/envelope.dart';

class AnalysisScreen extends StatelessWidget {
  AnalysisScreen({super.key});

  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    final daysRemaining = daysInMonth - daysElapsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi')),
      body: StreamBuilder<List<Expense>>(
        stream: _service.streamExpenses(),
        builder: (context, expSnapshot) {
          if (!expSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allExpenses = expSnapshot.data!;

          final thisMonthExpenses = allExpenses
              .where(
                (e) =>
                    e.date.isAfter(startOfThisMonth) ||
                    e.date.isAtSameMomentAs(startOfThisMonth),
              )
              .toList();
          final lastMonthExpenses = allExpenses
              .where(
                (e) =>
                    (e.date.isAfter(startOfLastMonth) ||
                        e.date.isAtSameMomentAs(startOfLastMonth)) &&
                    e.date.isBefore(startOfThisMonth),
              )
              .toList();

          final totalThisMonth = thisMonthExpenses.fold<double>(
            0,
            (s, e) => s + e.amount,
          );
          final totalLastMonth = lastMonthExpenses.fold<double>(
            0,
            (s, e) => s + e.amount,
          );

          final percentChange = totalLastMonth == 0
              ? 0.0
              : ((totalThisMonth - totalLastMonth) / totalLastMonth) * 100;

          // Categoria con la spesa più alta questo mese
          final byCategory = <String, double>{};
          for (final e in thisMonthExpenses) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
          }
          String topCategory = '';
          double topCategoryAmount = 0;
          byCategory.forEach((cat, amount) {
            if (amount > topCategoryAmount) {
              topCategory = cat;
              topCategoryAmount = amount;
            }
          });

          // Previsione fine mese: proietta il ritmo di spesa attuale
          final dailyAverage = daysElapsed == 0
              ? 0.0
              : totalThisMonth / daysElapsed;
          final projectedTotal = dailyAverage * daysInMonth;

          return StreamBuilder<List<Envelope>>(
            stream: _service.streamEnvelopes(),
            builder: (context, envSnapshot) {
              final envelopes = envSnapshot.data ?? [];

              // Buste a rischio: al ritmo attuale finiranno prima di fine mese
              final atRiskEnvelopes = envelopes.where((env) {
                if (env.budget == 0 || daysElapsed == 0) return false;
                final spentSoFar = env.budget - env.balance;
                final dailyRate = spentSoFar / daysElapsed;
                if (dailyRate == 0) return false;
                final daysUntilEmpty = env.balance / dailyRate;
                return daysUntilEmpty < daysRemaining && env.balance > 0;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCard(
                    icon: percentChange > 0 ? '\u26A0\uFE0F' : '\u2705',
                    title: 'Confronto con il mese scorso',
                    body: totalLastMonth == 0
                        ? 'Ancora nessun dato per il mese scorso.'
                        : 'Hai speso ${percentChange > 0 ? '${percentChange.toStringAsFixed(0)}% in pi\u00f9' : '${percentChange.abs().toStringAsFixed(0)}% in meno'} rispetto al mese scorso.',
                    color: percentChange > 0
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  if (topCategory.isNotEmpty)
                    _buildCard(
                      icon: '\uD83D\uDCCA',
                      title: 'Categoria con pi\u00f9 spesa',
                      body:
                          'Hai speso \u20ac${topCategoryAmount.toStringAsFixed(2)} in $topCategory questo mese.',
                      color: AppColors.secondary,
                    ),
                  _buildCard(
                    icon: '\uD83D\uDD2E',
                    title: 'Previsione fine mese',
                    body:
                        'Se continui con questo ritmo, a fine mese avrai speso circa \u20ac${projectedTotal.toStringAsFixed(2)}.',
                    color: AppColors.accent,
                  ),
                  for (final env in atRiskEnvelopes)
                    _buildCard(
                      icon: '\u26A0\uFE0F',
                      title: 'Attenzione: ${env.name}',
                      body:
                          'La busta "${env.name}" rischia di esaurirsi prima della fine del mese al ritmo attuale.',
                      color: AppColors.danger,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
