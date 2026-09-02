import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/habit_insights.dart';
import '../widgets/app_icons.dart';
import '../widgets/trial_quota_badge.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final _aiService = AiService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();

    String answer;
    try {
      final summary = await _buildSpendingSummary();
      answer = await _aiService.askAssistant(text, summary);
    } catch (_) {
      answer = 'Si è verificato un errore, riprova.';
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: answer, isUser: false));
        _isLoading = false;
      });
    }
  }

  /// Riassunto compatto (pochi numeri aggregati, mai transazioni singole né
  /// dati familiari) da passare a `chatWithAssistant`: tiene bassi i token
  /// e quindi il costo per richiesta, come da nota economica in CLAUDE.md.
  ///
  /// Punto 14 del piano AI Premium: arricchito con i segnali già calcolati
  /// nei blocchi precedenti (trend/medie per categoria, stato "on track"
  /// degli obiettivi) così la chat può rispondere a più tipi di domande
  /// senza bisogno di una nuova Cloud Function — sempre solo numeri già
  /// calcolati in Dart, mai nuovi calcoli delegati a Gemini.
  Future<String> _buildSpendingSummary() async {
    final now = DateTime.now();
    final expenses = await _firestoreService.streamExpenses().first;
    final incomes = await _firestoreService.streamIncomes().first;
    final challenges = await _firestoreService.streamChallenges().first;

    final monthExpenses = expenses.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final monthIncomes = incomes.where(
      (i) => i.date.year == now.year && i.date.month == now.month,
    );

    final byCategory = <String, double>{};
    for (final e in monthExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final totalSpeso = byCategory.values.fold(0.0, (s, v) => s + v);
    final totalEntrate = monthIncomes.fold(0.0, (s, i) => s + i.amount);

    final buffer = StringBuffer();
    if (byCategory.isNotEmpty) {
      final categorie = byCategory.entries
          .map((e) => '${e.key}: €${e.value.toStringAsFixed(0)}')
          .join(', ');
      buffer.writeln('Spese per categoria questo mese: $categorie.');
    } else {
      buffer.writeln('Nessuna spesa registrata questo mese.');
    }
    buffer.writeln(
      'Entrate: €${totalEntrate.toStringAsFixed(2)}   |   '
      'Spese: €${totalSpeso.toStringAsFixed(2)}',
    );

    final activeGoals = challenges.where(
      (c) =>
          c.type == ChallengeType.saving &&
          c.percentComplete < 1 &&
          c.monthlyQuota != null,
    );
    for (final goal in activeGoals) {
      final onTrack = goal.isOnTrack;
      final onTrackText = onTrack == null
          ? ''
          : (onTrack ? ' (in linea con il piano)' : ' (indietro sul piano)');
      buffer.writeln(
        'Obiettivo di risparmio "${goal.title}": quota mensile consigliata '
        '€${goal.monthlyQuota!.toStringAsFixed(2)}$onTrackText.',
      );
    }

    final habitSummary = HabitInsights.buildSummary(expenses, now: now);
    if (habitSummary.isNotEmpty) {
      buffer.writeln(habitSummary);
    }

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assistente AI',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TrialQuotaBadge(
              used: (u) => u.richiesteAiUsate,
              max: AppUser.trialMaxRichiesteAi,
              label: 'Richieste AI',
            ),
          ),
          const _MonthlyReportCard(),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Fai una domanda al tuo assistente finanziario!',
                      style: TextStyle(color: AppColors.neutral),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Chiedi qualcosa all\'AI...',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const AppIcon(
                      HeroIcons.paperAirplane,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.ink,
          fontSize: 14,
        ),
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary,
          child: AppIcon(HeroIcons.sparkles, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

/// "Il mio mese secondo l'AI" (punto 12 del piano): entrate/spese/risparmio
/// (numeri veri, mai inventati) + punto di forza/attenzione/consiglio
/// narrati dalla Cloud Function generateAiInsight, generati al massimo una
/// volta al mese e serviti dalla cache per il resto delle aperture. Questa
/// schermata è raggiungibile solo da utenti con accesso AI, quindi non
/// serve un controllo hasAi qui dentro.
class _MonthlyReportCard extends StatefulWidget {
  const _MonthlyReportCard();

  @override
  State<_MonthlyReportCard> createState() => _MonthlyReportCardState();
}

class _MonthlyReportCardState extends State<_MonthlyReportCard> {
  final _service = FirestoreService();
  final _aiService = AiService();
  bool _generating = false;
  bool _expanded = false;
  String? _error;

  String get _monthKey {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  void _ensureFresh(AiMonthlyReport? cached) {
    if (_generating || (cached != null && cached.monthKey == _monthKey)) {
      return;
    }
    _generating = true;
    _aiService.generateInsight(kind: 'monthly_report').then((_) {
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
    return StreamBuilder<AiMonthlyReport?>(
      stream: _service.streamAiMonthlyReport(),
      builder: (context, snapshot) {
        final cached = snapshot.data;
        final isFresh = cached != null && cached.monthKey == _monthKey;
        if (!isFresh) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _ensureFresh(cached),
          );
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: isFresh
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                child: Row(
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
                        'Il mio mese secondo l\'AI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isFresh)
                      AppIcon(
                        _expanded ? HeroIcons.chevronUp : HeroIcons.chevronDown,
                        color: AppColors.neutral,
                      ),
                  ],
                ),
              ),
              if (!isFresh) ...[
                const SizedBox(height: 6),
                Text(
                  _error ?? 'Sto preparando il report del mese...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
              if (isFresh) ...[
                const SizedBox(height: 8),
                Text(
                  'Entrate €${cached.totalEntrate.toStringAsFixed(0)}   |   '
                  'Spese €${cached.totalSpeso.toStringAsFixed(0)}   |   '
                  'Risparmio €${cached.risparmio.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  _reportLine(
                    HeroIcons.arrowTrendingUp,
                    AppColors.primary,
                    cached.puntoDiForza,
                  ),
                  const SizedBox(height: 4),
                  _reportLine(
                    HeroIcons.exclamationTriangle,
                    AppColors.warning,
                    cached.attenzione,
                  ),
                  const SizedBox(height: 4),
                  _reportLine(
                    HeroIcons.lightBulb,
                    AppColors.secondary,
                    cached.consiglio,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _reportLine(HeroIcons icon, Color color, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
