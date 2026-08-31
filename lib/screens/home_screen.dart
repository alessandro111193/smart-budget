import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
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
          appBar: AppBar(
            leading: const Icon(Icons.menu, color: AppColors.ink),
            title: Row(
              children: const [
                Icon(Icons.account_balance_wallet, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Spesa Intelligente',
                  style: TextStyle(color: AppColors.ink, fontSize: 17),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline, color: AppColors.ink),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FamilyScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart, color: AppColors.ink),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AnalysisScreen()),
                  );
                  _refresh();
                },
              ),
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: AppColors.ink),
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
              _goalRow(),
              const SizedBox(height: 20),
              _quickActions(context),
              const SizedBox(height: 24),
              _envelopesHeader(context),
              const SizedBox(height: 8),
              ...envelopes.take(4).map((e) => _envelopeTile(e)),
              const SizedBox(height: 16),
              _aiInsightCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _greetingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ciao Alessandro! 👋',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Hai il controllo delle tue finanze.',
              style: TextStyle(color: AppColors.neutral, fontSize: 13),
            ),
          ],
        ),
        StreamBuilder<List<Expense>>(
          stream: _service.streamExpenses(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            final livello = (count ~/ 5) + 1;
            final xp = count * 50;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Livello $livello\n$xp XP',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Disponibile',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '€ ${disponibile.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Entrate: €${entrate.toStringAsFixed(2)}   |   Spese: €${spese.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent.clamp(0, 1),
                  strokeWidth: 7,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Budget\nusato',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalRow() {
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
            const Icon(Icons.flag_outlined, size: 16, color: AppColors.neutral),
            const SizedBox(width: 6),
            Text(
              goal == null
                  ? 'Nessun obiettivo di risparmio impostato'
                  : 'Obiettivo di risparmio: €${goal.targetAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
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
            Icons.add_circle_outline,
            AppColors.primary,
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
            Icons.shopping_cart_outlined,
            AppColors.warning,
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
            Icons.qr_code_scanner,
            AppColors.accent,
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
            Icons.smart_toy_outlined,
            AppColors.secondary,
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
            Icons.list_alt_outlined,
            AppColors.neutral,
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: actions.map((a) => _actionButton(a)).toList(),
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
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: item.onTap,
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: item.color.withOpacity(0.12),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.ink),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _envelopesHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Le tue buste',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Text(e.icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentUsed.clamp(0, 1),
                      color: color,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${e.balance.toStringAsFixed(0)} / €${e.budget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(percentUsed * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: percentUsed > 1 ? AppColors.danger : color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiInsightCard(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _service.streamUser(),
      builder: (context, snapshot) {
        final hasAi = snapshot.data?.hasAiAccess ?? false;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "L'AI ha analizzato le tue spese",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAi
                          ? 'Apri l\'AI Assistant per i consigli aggiornati.'
                          : 'Attiva il trial per scoprire dove puoi risparmiare.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                hasAi ? const AiChatScreen() : PremiumScreen(),
                          ),
                        );
                        _refresh();
                      },
                      child: Text(
                        hasAi ? 'Apri chat →' : 'Scopri come →',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionItem(this.label, this.icon, this.color, this.onTap);
}
