import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
import '../models/family_income.dart';
import '../models/envelope.dart';
import '../services/ai_service.dart';
import '../services/family_insights.dart';
import '../services/family_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_icons.dart';
import '../widgets/family_premium_blocked_card.dart';
import '../widgets/monthly_trend_chart.dart';
import 'new_family_envelope_screen.dart';
import 'new_family_income_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final String familyId;
  const FamilyDashboardScreen({super.key, required this.familyId});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final _service = FamilyService();
  String _selectedScope = 'Famiglia'; // "Famiglia" oppure userId di un membro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard Famiglia',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      // Blocco D: senza questo controllo, un Premium/Trial scaduto
      // farebbe fallire per permessi le 4 stream sotto (envelopes/
      // expenses/incomes bloccate dalle Firestore Rules) — con
      // `.data ?? []` l'errore sarebbe passato inosservato, mostrando una
      // dashboard vuota invece di spiegare perché.
      body: StreamBuilder<Family?>(
        stream: _service.streamFamily(widget.familyId),
        builder: (context, familySnapshot) {
          final family = familySnapshot.data;
          if (family == null) return const SizedBox.shrink();
          return FamilyAccessGate(
            family: family,
            myUid: FirebaseAuth.instance.currentUser?.uid,
            title: 'Dashboard Famiglia',
            child: _dashboardBody(),
          );
        },
      ),
    );
  }

  Widget _dashboardBody() {
    return StreamBuilder<List<FamilyMember>>(
        stream: _service.streamMembers(widget.familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];

          return StreamBuilder<List<FamilyExpense>>(
            stream: _service.streamFamilyExpenses(widget.familyId),
            builder: (context, expSnapshot) {
              final expenses = expSnapshot.data ?? [];

              return StreamBuilder<List<FamilyIncome>>(
                stream: _service.streamFamilyIncomes(widget.familyId),
                builder: (context, incSnapshot) {
                  final incomes = incSnapshot.data ?? [];

                  return StreamBuilder<List<Envelope>>(
                    stream: _service.streamFamilyEnvelopes(widget.familyId),
                    builder: (context, envSnapshot) {
                      final envelopes = envSnapshot.data ?? [];

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _scopeSelector(members),
                          const SizedBox(height: 16),
                          _totalsCard(expenses, members),
                          const SizedBox(height: 12),
                          _incomesCard(incomes),
                          const SizedBox(height: 12),
                          _savingsCard(expenses, incomes, members),
                          const SizedBox(height: 12),
                          _categoryBreakdown(expenses, envelopes, members),
                          const SizedBox(height: 12),
                          _trendChart(expenses, members),
                          const SizedBox(height: 12),
                          _FamilyAnalysisCard(
                            expenses: expenses,
                            members: members,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Buste condivise',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewFamilyEnvelopeScreen(
                                        familyId: widget.familyId,
                                      ),
                                    ),
                                  ),
                                  icon: const AppIcon(
                                    HeroIcons.plus,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text('Nuova busta'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewFamilyIncomeScreen(
                                        familyId: widget.familyId,
                                      ),
                                    ),
                                  ),
                                  icon: const AppIcon(
                                    HeroIcons.plusCircle,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text('Nuova entrata'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (envelopes.isEmpty)
                            const Text(
                              'Nessuna busta familiare ancora creata.',
                              style: TextStyle(color: AppColors.neutral),
                            ),
                          ...envelopes.map((e) => _envelopeTile(e)),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
  }

  Widget _scopeSelector(List<FamilyMember> members) {
    final chips = ['Famiglia', ...members.map((m) => m.userId)];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips.map((c) {
          final label = c == 'Famiglia'
              ? 'Famiglia'
              : members.firstWhere((m) => m.userId == c).name;
          final selected = c == _selectedScope;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() => _selectedScope = c),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _totalsCard(List<FamilyExpense> expenses, List<FamilyMember> members) {
    final isFamily = _selectedScope == 'Famiglia';
    final total = isFamily
        ? _service.familyTotalExpenses(expenses)
        : _service.memberExpenseTotal(expenses, _selectedScope, members.length);

    final sharedQuota = !isFamily
        ? expenses
              .where((e) => e.type == FamilyExpenseType.shared)
              .fold<double>(
                0,
                (s, e) => s + e.quotaFor(_selectedScope, members.length),
              )
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFamily ? 'Spese totali famiglia' : 'Le tue spese (quota)',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '€${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sharedQuota != null) ...[
            const SizedBox(height: 8),
            Text(
              'di cui quota condivisa: €${sharedQuota.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _incomesCard(List<FamilyIncome> incomes) {
    final isFamily = _selectedScope == 'Famiglia';
    final total = isFamily
        ? _service.familyTotalIncomes(incomes)
        : _service.memberIncomeTotal(incomes, _selectedScope);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isFamily ? 'Entrate totali famiglia' : 'Le tue entrate',
              style: const TextStyle(
                color: AppColors.neutral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '€${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Risparmio (entrate − spese) nello scope selezionato — trovato mancante
  /// nell'audit funzionale del 2026-09-03 rispetto alla richiesta esplicita
  /// dell'utente, aggiunto qui con lo stesso stile delle altre card.
  Widget _savingsCard(
    List<FamilyExpense> expenses,
    List<FamilyIncome> incomes,
    List<FamilyMember> members,
  ) {
    final isFamily = _selectedScope == 'Famiglia';
    final totalExpenses = isFamily
        ? _service.familyTotalExpenses(expenses)
        : _service.memberExpenseTotal(expenses, _selectedScope, members.length);
    final totalIncomes = isFamily
        ? _service.familyTotalIncomes(incomes)
        : _service.memberIncomeTotal(incomes, _selectedScope);
    final savings = totalIncomes - totalExpenses;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isFamily ? 'Risparmio famiglia' : 'Il tuo risparmio (quota)',
            style: const TextStyle(
              color: AppColors.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '€${savings.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: savings >= 0 ? AppColors.primary : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  /// Andamento delle spese negli ultimi 6 mesi nello scope selezionato —
  /// stesso `MonthlyTrendChart` già usato per la versione personale
  /// (`analysis_screen.dart`), trovato mancante lato famiglia nell'audit
  /// (prima c'era solo il confronto mese corrente vs precedente).
  Widget _trendChart(List<FamilyExpense> expenses, List<FamilyMember> members) {
    final now = DateTime.now();
    final isFamily = _selectedScope == 'Famiglia';
    const monthLabels = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    final trend = <({String label, double total})>[];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonthDate = DateTime(now.year, now.month - i + 1, 1);
      final monthExpenses = expenses
          .where(
            (e) =>
                !e.date.isBefore(monthDate) && e.date.isBefore(nextMonthDate),
          )
          .toList();
      final total = isFamily
          ? _service.familyTotalExpenses(monthExpenses)
          : _service.memberExpenseTotal(
              monthExpenses, _selectedScope, members.length,
            );
      trend.add((label: monthLabels[monthDate.month - 1], total: total));
    }
    if (!trend.any((t) => t.total > 0)) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Andamento spese ultimi 6 mesi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 140, child: MonthlyTrendChart(data: trend)),
        ],
      ),
    );
  }

  /// Ripartizione per busta delle spese nello scope selezionato (Famiglia
  /// o singolo membro). La busta funge da "categoria" perché FamilyExpense
  /// non ha un campo categoria proprio — stessa scelta già fatta per le
  /// spese personali dell'app (vedi Blocco Famiglia in CLAUDE.md), non
  /// introduce un nuovo pattern dati incoerente.
  Widget _categoryBreakdown(
    List<FamilyExpense> expenses,
    List<Envelope> envelopes,
    List<FamilyMember> members,
  ) {
    final isFamily = _selectedScope == 'Famiglia';
    final byEnvelope = <String, double>{};
    for (final e in expenses) {
      final quota = isFamily
          ? e.amount
          : e.quotaFor(_selectedScope, members.length);
      if (quota <= 0) continue;
      byEnvelope[e.envelopeId] = (byEnvelope[e.envelopeId] ?? 0) + quota;
    }
    final entries = byEnvelope.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxValue = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Per busta',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final env = envelopes.cast<Envelope?>().firstWhere(
              (e) => e?.id == entry.key,
              orElse: () => null,
            );
            final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
            final color =
                AppColors.envelopeColors[i % AppColors.envelopeColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '€${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0, 1),
                      color: color,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _envelopeTile(Envelope e) {
    final index = e.id.hashCode % AppColors.envelopeColors.length;
    final color = AppColors.envelopeColors[index.abs()];
    final percent = e.budget == 0 ? 0.0 : (e.budget - e.balance) / e.budget;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewFamilyEnvelopeScreen(
              familyId: widget.familyId,
              envelope: e,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(e.icon, style: const TextStyle(fontSize: 18)),
        ),
        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              color: color,
              backgroundColor: Colors.grey.shade200,
              minHeight: 5,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '€${e.balance.toStringAsFixed(0)} / €${e.budget.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            IconButton(
              icon: const AppIcon(
                HeroIcons.trash,
                color: AppColors.danger,
                size: 20,
              ),
              tooltip: 'Elimina busta familiare',
              onPressed: () => _confirmDeleteEnvelope(context, e),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEnvelope(BuildContext context, Envelope e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminare la busta?'),
        content: Text(
          'Vuoi davvero eliminare la busta familiare "${e.name}"? '
          'Le spese/entrate già registrate restano nello storico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              await _service.deleteFamilyEnvelope(widget.familyId, e.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(
              'Elimina',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto 9 del piano AI Premium: confronto mese su mese delle spese
/// familiari (totale e per membro) già calcolato in Dart
/// (FamilyInsights, zero costo); solo la narrazione finale passa da
/// Gemini, on-demand, sempre con l'istruzione esplicita di non giudicare
/// nessuno. Visibile solo a Premium/Trial (l'accesso AI è personale, non
/// di famiglia, quindi si verifica con FirestoreService.streamUser()).
class _FamilyAnalysisCard extends StatefulWidget {
  const _FamilyAnalysisCard({required this.expenses, required this.members});

  final List<FamilyExpense> expenses;
  final List<FamilyMember> members;

  @override
  State<_FamilyAnalysisCard> createState() => _FamilyAnalysisCardState();
}

class _FamilyAnalysisCardState extends State<_FamilyAnalysisCard> {
  final _service = FirestoreService();
  final _aiService = AiService();
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _analyze() async {
    final summary = FamilyInsights.buildSummary(
      widget.expenses,
      widget.members,
    );
    if (summary.isEmpty) {
      setState(() {
        _error = 'Non ci sono ancora spese familiari sufficienti per '
            'un\'analisi.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _aiService.generateInsight(
        kind: 'family_analysis',
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
                      'Analisi AI della famiglia',
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
                            ? 'Analizza le spese della famiglia'
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
