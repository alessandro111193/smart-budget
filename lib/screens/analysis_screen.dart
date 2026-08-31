import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import '../services/habit_insights.dart';
import '../models/app_user.dart';
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
      appBar: AppBar(title: const Text('Statistiche')),
      body: StreamBuilder<List<Expense>>(
        stream: _service.streamExpenses(),
        builder: (context, expSnapshot) {
          if (!expSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allExpenses = expSnapshot.data!;

          final thisMonthExpenses = allExpenses
              .where((e) => !e.date.isBefore(startOfThisMonth))
              .toList();
          final lastMonthExpenses = allExpenses
              .where(
                (e) =>
                    !e.date.isBefore(startOfLastMonth) &&
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

          final byCategory = <String, double>{};
          for (final e in thisMonthExpenses) {
            byCategory[e.category.isEmpty ? 'Altro' : e.category] =
                (byCategory[e.category.isEmpty ? 'Altro' : e.category] ?? 0) +
                e.amount;
          }
          final categoryEntries = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final dailyAverage = daysElapsed == 0
              ? 0.0
              : totalThisMonth / daysElapsed;
          final projectedTotal = dailyAverage * daysInMonth;

          return StreamBuilder<List<Envelope>>(
            stream: _service.streamEnvelopes(),
            builder: (context, envSnapshot) {
              final envelopes = envSnapshot.data ?? [];
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
                  // Card totale + confronto mese scorso
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Questo mese',
                          style: TextStyle(color: AppColors.neutral),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Hai speso €${totalThisMonth.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (totalLastMonth > 0)
                              Text(
                                '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: percentChange > 0
                                      ? AppColors.danger
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (totalLastMonth > 0)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  'vs mese scorso',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (categoryEntries.isNotEmpty) ...[
                    const Text(
                      'Spese per categoria',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: PieChart(
                              PieChartData(
                                sections: List.generate(
                                  categoryEntries.length,
                                  (i) {
                                    final entry = categoryEntries[i];
                                    final percent = totalThisMonth == 0
                                        ? 0.0
                                        : (entry.value / totalThisMonth) * 100;
                                    return PieChartSectionData(
                                      value: entry.value,
                                      color:
                                          AppColors.envelopeColors[i %
                                              AppColors.envelopeColors.length],
                                      title: '${percent.toStringAsFixed(0)}%',
                                      radius: 45,
                                      titleStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                                centerSpaceRadius: 32,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(categoryEntries.length, (
                                i,
                              ) {
                                final entry = categoryEntries[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              AppColors.envelopeColors[i %
                                                  AppColors
                                                      .envelopeColors
                                                      .length],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                  const SizedBox(height: 4),
                  _HabitAnalysisCard(expenses: allExpenses),
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

/// Punti 3+5 del piano AI Premium: media mensile per categoria e
/// variazioni recenti sono già calcolate in Dart (HabitInsights, zero
/// costo); solo la narrazione finale — pattern rilevato + consiglio di
/// risparmio — passa da Gemini, on-demand, mai da sola all'apertura
/// schermo. Visibile solo a Premium/Trial.
class _HabitAnalysisCard extends StatefulWidget {
  const _HabitAnalysisCard({required this.expenses});

  final List<Expense> expenses;

  @override
  State<_HabitAnalysisCard> createState() => _HabitAnalysisCardState();
}

class _HabitAnalysisCardState extends State<_HabitAnalysisCard> {
  final _service = FirestoreService();
  final _aiService = AiService();
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _analyze() async {
    final summary = HabitInsights.buildSummary(widget.expenses);
    if (summary.isEmpty) {
      setState(() {
        _error = 'Continua a registrare le spese: mi servono almeno due '
            'mesi di storico per un\'analisi affidabile.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _aiService.generateInsight(
        kind: 'habit_analysis',
        summary: summary,
      );
      if (!mounted) return;
      setState(() {
        _result = data['text'] as String? ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, snapshot) {
        final hasAi = snapshot.data?.hasAiAccess ?? false;
        if (!hasAi) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
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
                    child: Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Analisi abitudini di spesa',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 10),
                Text(_result!, style: const TextStyle(fontSize: 13)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.insights_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                  label: Text(
                    _loading
                        ? 'Sto analizzando...'
                        : (_result == null
                            ? 'Analizza le mie abitudini con l\'AI'
                            : 'Rianalizza'),
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
            ],
          ),
        );
      },
    );
  }
}
