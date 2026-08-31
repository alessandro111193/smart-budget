import '../models/family.dart';
import '../models/family_expense.dart';

/// Confronto mese su mese delle spese familiari (totale e per membro) —
/// solo calcolo Dart/Firestore, zero chiamate AI. Punto 9 del piano AI
/// Premium: "informazioni utili per il budget, mai giudizi sulle persone"
/// — questo helper produce solo numeri e percentuali, nessun testo
/// valutativo; l'eventuale narrazione (via generateAiInsight) riceve
/// esplicitamente l'istruzione di non giudicare nessuno.
class FamilyInsights {
  static const double _significantChangePercent = 10;

  /// Restituisce una stringa vuota se non c'è ancora nessuna spesa in
  /// questo mese o nel mese scorso: in quel caso il chiamante non deve
  /// invocare l'AI.
  static String buildSummary(
    List<FamilyExpense> expenses,
    List<FamilyMember> members, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final startOfThisMonth = DateTime(today.year, today.month, 1);
    final startOfLastMonth = DateTime(today.year, today.month - 1, 1);

    final thisMonth = expenses
        .where((e) => !e.date.isBefore(startOfThisMonth))
        .toList();
    final lastMonth = expenses
        .where(
          (e) =>
              !e.date.isBefore(startOfLastMonth) &&
              e.date.isBefore(startOfThisMonth),
        )
        .toList();

    if (thisMonth.isEmpty && lastMonth.isEmpty) return '';

    double totalOf(List<FamilyExpense> list) =>
        list.fold(0.0, (s, e) => s + e.amount);
    final totalThisMonth = totalOf(thisMonth);
    final totalLastMonth = totalOf(lastMonth);

    final buffer = StringBuffer(
      'Spese familiari questo mese: €${totalThisMonth.toStringAsFixed(0)} '
      '(mese scorso: €${totalLastMonth.toStringAsFixed(0)}).\n',
    );

    if (totalLastMonth > 0) {
      final change =
          ((totalThisMonth - totalLastMonth) / totalLastMonth) * 100;
      if (change.abs() >= _significantChangePercent) {
        buffer.writeln(
          'Variazione totale: ${change >= 0 ? '+' : ''}'
          '${change.toStringAsFixed(0)}% rispetto al mese scorso.',
        );
      }
    }

    final memberLines = <String>[];
    for (final member in members) {
      final thisMonthQuota = thisMonth.fold(
        0.0,
        (s, e) => s + e.quotaFor(member.userId, members.length),
      );
      final lastMonthQuota = lastMonth.fold(
        0.0,
        (s, e) => s + e.quotaFor(member.userId, members.length),
      );
      if (thisMonthQuota <= 0 && lastMonthQuota <= 0) continue;
      if (lastMonthQuota > 0) {
        final change =
            ((thisMonthQuota - lastMonthQuota) / lastMonthQuota) * 100;
        memberLines.add(
          '${member.name}: €${thisMonthQuota.toStringAsFixed(0)} questo '
          'mese (${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% '
          'vs mese scorso)',
        );
      } else {
        memberLines.add(
          '${member.name}: €${thisMonthQuota.toStringAsFixed(0)} questo '
          'mese',
        );
      }
    }
    if (memberLines.isNotEmpty) {
      buffer.writeln('Per membro: ${memberLines.join(', ')}.');
    }

    return buffer.toString().trim();
  }
}
