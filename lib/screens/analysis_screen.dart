import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import '../services/habit_insights.dart';
import '../models/app_user.dart';
import '../models/expense.dart';
import '../models/envelope.dart';
import '../models/income.dart';

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

          // Andamento spese ultimi 6 mesi (incluso quello corrente),
          // sempre da dati reali (allExpenses), mai valori statici.
          final monthlyTrend = <({String label, double total})>[];
          for (int i = 5; i >= 0; i--) {
            final monthDate = DateTime(now.year, now.month - i, 1);
            final nextMonthDate = DateTime(now.year, now.month - i + 1, 1);
            final total = allExpenses
                .where(
                  (e) =>
                      !e.date.isBefore(monthDate) &&
                      e.date.isBefore(nextMonthDate),
                )
                .fold<double>(0, (s, e) => s + e.amount);
            const monthLabels = [
              'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
              'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
            ];
            monthlyTrend.add(
              (label: monthLabels[monthDate.month - 1], total: total),
            );
          }

          return StreamBuilder<List<Income>>(
            stream: _service.streamIncomes(),
            builder: (context, incSnapshot) {
              final allIncomes = incSnapshot.data ?? [];
              final thisMonthIncomes = allIncomes
                  .where((i) => !i.date.isBefore(startOfThisMonth))
                  .toList();
              final totalIncomeThisMonth = thisMonthIncomes.fold<double>(
                0,
                (s, i) => s + i.amount,
              );
              final netThisMonth = totalIncomeThisMonth - totalThisMonth;

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

              final byEnvelope = <String, double>{};
              for (final e in thisMonthExpenses) {
                byEnvelope[e.envelopeId] =
                    (byEnvelope[e.envelopeId] ?? 0) + e.amount;
              }
              final envelopeSpendEntries =
                  byEnvelope.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              final maxEnvelopeSpend = envelopeSpendEntries.isEmpty
                  ? 0.0
                  : envelopeSpendEntries.first.value;

              final totalBudget = _service.totalBudget(envelopes);
              final totalDisponibile = _service.totalDisponibile(envelopes);
              final totalSpesoComplessivo = _service.totalSpeso(envelopes);

              final budgetGiornalieroResiduo =
                  daysRemaining > 0 ? totalDisponibile / daysRemaining : null;

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
                  const SizedBox(height: 12),

                  // Entrate / Spese / Saldo del mese corrente, sempre da
                  // dati reali (Expense/Income di questo mese).
                  Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          label: 'Entrate',
                          value: totalIncomeThisMonth,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statTile(
                          label: 'Spese',
                          value: totalThisMonth,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statTile(
                          label: 'Saldo',
                          value: netThisMonth,
                          color: netThisMonth >= 0
                              ? AppColors.primary
                              : AppColors.danger,
                        ),
                      ),
                    ],
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

                  if (envelopeSpendEntries.isNotEmpty) ...[
                    const Text(
                      'Spese per busta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(envelopeSpendEntries.length, (i) {
                      final entry = envelopeSpendEntries[i];
                      final env = envelopes.cast<Envelope?>().firstWhere(
                        (e) => e?.id == entry.key,
                        orElse: () => null,
                      );
                      final ratio = maxEnvelopeSpend == 0
                          ? 0.0
                          : entry.value / maxEnvelopeSpend;
                      final color = AppColors
                          .envelopeColors[i % AppColors.envelopeColors.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    env == null
                                        ? 'Busta eliminata'
                                        : '${env.icon} ${env.name}',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '\u20ac${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0, 1),
                                color: color,
                                backgroundColor: Colors.grey.shade200,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  if (monthlyTrend.any((m) => m.total > 0)) ...[
                    const Text(
                      'Andamento ultimi 6 mesi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _MonthlyTrendChart(data: monthlyTrend),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          label: 'Budget totale',
                          value: totalBudget,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statTile(
                          label: 'Utilizzato',
                          value: totalSpesoComplessivo,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statTile(
                          label: 'Rimanente',
                          value: totalDisponibile,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCard(
                    icon: '\uD83D\uDD2E',
                    title: 'Previsione fine mese',
                    body:
                        'Se continui con questo ritmo, a fine mese avrai speso circa \u20ac${projectedTotal.toStringAsFixed(2)}.'
                        '\nMedia giornaliera: \u20ac${dailyAverage.toStringAsFixed(2)} \u00B7 '
                        'Mancano $daysRemaining giorni a fine mese'
                        '${budgetGiornalieroResiduo != null ? ' \u00B7 Budget residuo: \u20ac${budgetGiornalieroResiduo.toStringAsFixed(2)}/giorno' : ''}.',
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
          );
        },
      ),
    );
  }

  Widget _statTile({
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.neutral),
          ),
          const SizedBox(height: 2),
          Text(
            '€${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
                    child: AppIcon(
                      HeroIcons.sparkles,
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
                      : const AppIcon(
                          HeroIcons.sparkles,
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

/// Grafico a barre dell'andamento delle spese negli ultimi 6 mesi (incluso
/// quello corrente). Un'unica serie (spesa totale mensile): un solo colore,
/// nessuna legenda necessaria, valore esatto al tocco su ciascuna barra.
class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.data});

  final List<({String label, double total})> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    final maxY = maxValue == 0 ? 1.0 : maxValue * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '€${rod.toY.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[i].label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(data.length, (i) {
          final d = data[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: d.total,
                color: AppColors.primary,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
