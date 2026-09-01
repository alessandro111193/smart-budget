import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../theme/icon_palette.dart';
import '../services/firestore_service.dart';
import '../services/budget_insights.dart';
import '../services/ai_service.dart';
import '../models/envelope.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/challenge.dart';
import '../models/app_user.dart';
import 'new_expense_screen.dart';
import 'new_income_screen.dart';
import 'ai_chat_screen.dart';
import 'premium_screen.dart';
import 'buste_screen.dart';
import 'analysis_screen.dart';
import 'challenge_screen.dart';
import 'family_screen.dart';
import 'scan_receipt_screen.dart';
import 'shopping_list_screen.dart';
import '../widgets/app_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = FirestoreService();

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Envelope>>(
      stream: _service.streamEnvelopes(),
      builder: (context, envSnapshot) {
        final envelopes = envSnapshot.data ?? [];
        final totalDisponibile = _service.totalDisponibile(envelopes);
        final totalSpeso = _service.totalSpeso(envelopes);
        final totalBudget = _service.totalBudget(envelopes);
        final percentUsed = totalBudget == 0 ? 0.0 : totalSpeso / totalBudget;

        return Scaffold(
          drawer: _buildDrawer(context),
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.ink),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Row(
              children: const [
                Icon(Icons.account_balance_wallet, color: AppColors.primary),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Spesa Intelligente',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.ink, fontSize: 17),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const AppIcon(
                  HeroIcons.users,
                  color: IconPalette.testo,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FamilyScreen()),
                  );
                },
              ),
              IconButton(
                icon: const AppIcon(
                  HeroIcons.chartBarSquare,
                  color: IconPalette.testo,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AnalysisScreen()),
                  );
                  _refresh();
                },
              ),
              IconButton(
                icon: const AppIcon(
                  HeroIcons.trophy,
                  color: IconPalette.testo,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChallengeScreen()),
                  );
                  _refresh();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _greetingRow(),
              const SizedBox(height: 16),
              StreamBuilder<List<Income>>(
                stream: _service.streamIncomes(),
                builder: (context, incSnapshot) {
                  final incomes = incSnapshot.data ?? [];
                  final totalEntrate = incomes.fold<double>(
                    0,
                    (s, i) => s + i.amount,
                  );
                  return _balanceCard(
                    totalDisponibile,
                    totalEntrate,
                    totalSpeso,
                    percentUsed,
                  );
                },
              ),
              const SizedBox(height: 16),
              _periodGoalRow(),
              const SizedBox(height: 20),
              _quickActions(context),
              const SizedBox(height: 24),
              _envelopesHeader(context),
              const SizedBox(height: 8),
              ...envelopes.take(4).map((e) => _envelopeTile(e)),
              const SizedBox(height: 8),
              _budgetAlertsCard(envelopes),
              const SizedBox(height: 8),
              _aiInsightCard(context),
            ],
          ),
        );
      },
    );
  }

  /// Drawer minimale collegato all'icona hamburger dell'AppBar (in
  /// precedenza presente solo come icona decorativa, senza alcuna azione):
  /// unico punto dell'app da cui l'utente può disconnettersi. Non è un
  /// redesign della Home — l'aspetto della schermata resta invariato,
  /// questo è un pannello separato che si apre sopra di essa.
  Widget _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName;
    final email = user?.email ?? '';
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: AppIcon(HeroIcons.userCircle, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (name == null || name.isEmpty) ? 'Il tuo nome' : name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: (name == null || name.isEmpty)
                                ? AppColors.neutral
                                : AppColors.ink,
                            fontStyle: (name == null || name.isEmpty)
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(
                      HeroIcons.pencilSquare,
                      size: 20,
                      color: AppColors.neutral,
                    ),
                    tooltip: 'Modifica nome',
                    onPressed: () => _editDisplayName(context, name),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const AppIcon(
                HeroIcons.arrowRightOnRectangle,
                color: AppColors.danger,
              ),
              title: const Text(
                'Esci',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context); // chiude il drawer
                await FirebaseAuth.instance.signOut();
                // main.dart rileva il cambio di stato auth e mostra da solo
                // la schermata di login, nessuna navigazione manuale qui.
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Permette di impostare/modificare il nome mostrato nel saluto della
  /// Home (prima era sempre "Alessandro" fisso, indipendentemente da chi
  /// avesse fatto login) e nella famiglia (FamilyService.createFamily usa
  /// già FirebaseAuth.currentUser?.displayName come nome del proprietario).
  Future<void> _editDisplayName(BuildContext context, String? currentName) async {
    final controller = TextEditingController(text: currentName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Il tuo nome'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Come vuoi essere chiamato?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Salva',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.updateDisplayName(newName.isEmpty ? null : newName);
    await user.reload();
    if (!mounted || !context.mounted) return;
    Navigator.pop(context); // chiude il drawer per mostrare subito il saluto aggiornato
    setState(() {});
  }

  Widget _greetingRow() {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    final greeting = (name == null || name.isEmpty)
        ? 'Ciao! 👋'
        : 'Ciao $name! 👋';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Hai il controllo delle tue finanze.',
                style: TextStyle(color: AppColors.neutral, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        StreamBuilder<List<Expense>>(
          stream: _service.streamExpenses(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            final livello = (count ~/ 5) + 1;
            final xp = count * 50;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    HeroIcons.star,
                    solid: true,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livello $livello',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '$xp XP',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _balanceCard(
    double disponibile,
    double entrate,
    double spese,
    double percent,
  ) {
    final clampedPercent = percent.clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF139D77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disponibile',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '€ ${disponibile.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: clampedPercent,
                        strokeWidth: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(percent * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Budget\nusato',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.neutral,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Entrate: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '€ ${entrate.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '|',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Spese: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '€ ${spese.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _monthNames = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];

  String _currentPeriodLabel() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return 'Periodo: 1 - $lastDay ${_monthNames[now.month - 1]}';
  }

  Widget _periodGoalRow() {
    return StreamBuilder<List<Challenge>>(
      stream: _service.streamChallenges(),
      builder: (context, snapshot) {
        final challenges = snapshot.data ?? [];
        Challenge? goal;
        for (final c in challenges) {
          if (c.type == ChallengeType.saving) {
            goal = c;
            break;
          }
        }
        return Row(
          children: [
            const AppIcon(
              HeroIcons.calendarDays,
              size: 14,
              color: AppColors.neutral,
            ),
            const SizedBox(width: 6),
            Text(
              _currentPeriodLabel(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  const AppIcon(
                    HeroIcons.flag,
                    size: 14,
                    color: AppColors.neutral,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      goal == null
                          ? 'Nessun obiettivo di risparmio impostato'
                          : 'Obiettivo di risparmio: €${goal.targetAmount.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quickActions(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasAi = user?.hasAiAccess ?? false;

        final actions = [
          _ActionItem(
            'Nuova\nentrata',
            ActionType.nuovaEntrata,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewIncomeScreen()),
              );
              _refresh();
            },
          ),
          _ActionItem(
            'Aggiungi\nspesa',
            ActionType.nuovaSpesa,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewExpenseScreen()),
              );
              _refresh();
            },
          ),
          _ActionItem(
            'Scan\nscontrino',
            ActionType.scanner,
            () => _goPremiumGated(context, hasAi, () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
              );
              _refresh();
            }),
          ),
          _ActionItem(
            'AI\nAssistant',
            ActionType.aiAssistant,
            () => _goPremiumGated(context, hasAi, () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
              _refresh();
            }),
          ),
          _ActionItem(
            'Lista\nspesa',
            ActionType.listaSpesa,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              );
              _refresh();
            },
          ),
        ];

        return Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _actionButton(a),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _goPremiumGated(
    BuildContext context,
    bool hasAi,
    VoidCallback onAllowed,
  ) {
    if (hasAi) {
      onAllowed();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PremiumScreen()),
      );
    }
  }

  Widget _actionButton(_ActionItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionIcon(type: item.type, size: 40),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _envelopesHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Le tue buste',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusteScreen()),
            );
            _refresh();
          },
          child: const Text('Vedi tutte'),
        ),
      ],
    );
  }

  Widget _envelopeTile(Envelope e) {
    final index = e.id.hashCode % AppColors.envelopeColors.length;
    final color = AppColors.envelopeColors[index.abs()];
    final percentUsed = e.budget == 0 ? 0.0 : (e.budget - e.balance) / e.budget;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(e.icon, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '€${e.balance.toStringAsFixed(0)} ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        TextSpan(
                          text: '/ €${e.budget.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(percentUsed * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: percentUsed > 1 ? AppColors.danger : color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentUsed.clamp(0, 1),
              color: color,
              backgroundColor: const Color(0xFFE2E8F0),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  /// Avvisi solo Dart/Firestore (nessuna chiamata AI): esaurimento busta,
  /// soglia di utilizzo alta, proiezione di fine mese al ritmo attuale.
  /// Disponibili anche su Free, a differenza della card AI sotto.
  Widget _budgetAlertsCard(List<Envelope> envelopes) {
    if (envelopes.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Expense>>(
      stream: _service.streamExpenses(),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final alerts = BudgetInsights.compute(
          envelopes: envelopes,
          expenses: expenses,
        );
        if (alerts.isEmpty) return const SizedBox.shrink();
        final shown = alerts.take(3).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avvisi budget',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...shown.map((a) {
                final isDanger = a.severity == BudgetAlertSeverity.danger;
                final color = isDanger ? AppColors.danger : AppColors.warning;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: color.withOpacity(0.15),
                        child: AppIcon(
                          isDanger
                              ? HeroIcons.exclamationCircle
                              : HeroIcons.exclamationTriangle,
                          size: 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.message,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Su Free mostra l'invito al trial (invariato). Su Premium/Trial mostra
  /// il "Consiglio di oggi" reale, generato una volta al giorno dalla
  /// Cloud Function generateAiInsight e servito dalla cache per il resto
  /// delle aperture — vedi _DailyTipContent.
  Widget _aiInsightCard(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, snapshot) {
        final hasAi = snapshot.data?.hasAiAccess ?? false;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const AppIcon(
                  HeroIcons.sparkles,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasAi
                    ? _DailyTipContent(
                        onOpenChat: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AiChatScreen(),
                            ),
                          );
                          _refresh();
                        },
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "L'AI ha analizzato le tue spese",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Attiva il trial per scoprire dove puoi '
                            'risparmiare.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.neutral,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PremiumScreen(),
                                ),
                              );
                              _refresh();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Scopri come',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  AppIcon(
                                    HeroIcons.arrowRight,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Contenuto del "Consiglio di oggi": legge la cache aiDailyTip e, solo se
/// non è più valida per la data odierna, chiede alla Cloud Function di
/// rigenerarla (che a sua volta la riscrive in cache) — mai più di una
/// generazione al giorno per utente.
class _DailyTipContent extends StatefulWidget {
  const _DailyTipContent({required this.onOpenChat});

  final VoidCallback onOpenChat;

  @override
  State<_DailyTipContent> createState() => _DailyTipContentState();
}

class _DailyTipContentState extends State<_DailyTipContent> {
  final _service = FirestoreService();
  final _aiService = AiService();
  bool _generating = false;
  String? _error;

  String get _todayKey {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  void _ensureFresh(AiDailyTip? cached) {
    if (_generating || (cached != null && cached.dateKey == _todayKey)) {
      return;
    }
    _generating = true;
    _aiService.generateInsight(kind: 'daily_tip').then((_) {
      if (mounted) setState(() => _generating = false);
    }).catchError((Object e) {
      if (mounted) {
        setState(() {
          _generating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AiDailyTip?>(
      stream: _service.streamAiDailyTip(),
      builder: (context, snapshot) {
        final cached = snapshot.data;
        final isFresh = cached != null && cached.dateKey == _todayKey;
        if (!isFresh) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _ensureFresh(cached),
          );
        }

        final subtitle = isFresh
            ? cached.text
            : (_error ?? 'Sto preparando il tuo consiglio di oggi...');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consiglio di oggi',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onOpenChat,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Chiedi all'AI",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 4),
                    AppIcon(HeroIcons.arrowRight, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionItem {
  final String label;
  final ActionType type;
  final VoidCallback onTap;
  _ActionItem(this.label, this.type, this.onTap);
}
