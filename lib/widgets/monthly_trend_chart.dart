import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grafico a barre dell'andamento mensile (spese, entrate o qualunque altro
/// totale), colore singolo (unica serie, nessuna legenda necessaria), con
/// tooltip al tocco. Estratto da `analysis_screen.dart` (dove è nato per lo
/// storico spese personale) per essere riusato anche in
/// `family_dashboard_screen.dart`, invece di duplicarlo.
class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({super.key, required this.data});

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
