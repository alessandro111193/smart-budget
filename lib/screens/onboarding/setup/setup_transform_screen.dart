import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/challenge.dart';
import '../../../models/envelope.dart';
import '../../../models/income.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/icon_palette.dart';
import '../../../widgets/onboarding/onboarding_animations.dart';
import '../../../widgets/onboarding/onboarding_widgets.dart';

/// Ultimo passaggio: legge i dati VERI appena salvati (nome, entrate,
/// buste, obiettivo) e li anima in una mini Home — poi, al tocco di
/// "INIZIA", segna la configurazione come completata.
/// `FirestoreService.markSetupCompleted()` fa scattare `_RootGate` (che
/// ascolta lo stesso stream) verso la Home reale: nessuna navigazione
/// manuale, nessuna seconda Home da mantenere allineata a quella vera.
class SetupTransformScreen extends StatefulWidget {
  const SetupTransformScreen({super.key});

  @override
  State<SetupTransformScreen> createState() => _SetupTransformScreenState();
}

class _SetupTransformScreenState extends State<SetupTransformScreen> {
  final _service = FirestoreService();
  bool _finishing = false;

  Future<void> _finish() async {
    setState(() => _finishing = true);
    await _service.markSetupCompleted();
    // _RootGate riascolta streamSetupCompleted() e mostra da solo la Home
    // reale: non serve navigare manualmente da qui.
  }

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    return Scaffold(
      backgroundColor: IconPalette.sfondoAlt,
      body: SafeArea(
        child: StreamBuilder<List<Envelope>>(
          stream: _service.streamEnvelopes(),
          builder: (context, envSnap) {
            final envelopes = envSnap.data ?? [];
            return StreamBuilder<List<Income>>(
              stream: _service.streamIncomes(),
              builder: (context, incSnap) {
                final incomes = incSnap.data ?? [];
                final totalIncome = incomes.fold<double>(
                  0,
                  (s, i) => s + i.amount,
                );
                return StreamBuilder<List<Challenge>>(
                  stream: _service.streamChallenges(),
                  builder: (context, chSnap) {
                    final goal = (chSnap.data ?? [])
                        .where((c) => c.type == ChallengeType.saving)
                        .cast<Challenge?>()
                        .firstWhere((c) => true, orElse: () => null);
                    final totalBudget = envelopes.fold<double>(
                      0,
                      (s, e) => s + e.budget,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DelayedEntrance(
                            child: Text(
                              (name == null || name.isEmpty)
                                  ? 'Perfetto!'
                                  : 'Perfetto, $name!',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: IconPalette.testo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DelayedEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: const Text(
                              'Ecco il tuo budget, pronto per iniziare.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          DelayedEntrance(
                            delay: const Duration(milliseconds: 300),
                            child: AnimatedCounter(
                              end: totalBudget,
                              delay: const Duration(milliseconds: 350),
                              duration: const Duration(milliseconds: 1000),
                              builder: (context, value) => DemoBalanceCard(
                                disponibile: value,
                                entrate: totalIncome,
                                spese: 0,
                              ),
                            ),
                          ),
                          if (envelopes.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            DelayedEntrance(
                              delay: const Duration(milliseconds: 700),
                              child: const Text(
                                'Le tue buste',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(envelopes.length, (i) {
                              final e = envelopes[i];
                              return DelayedEntrance(
                                delay: Duration(
                                  milliseconds: 800 + i * 130,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DemoCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          e.icon,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            e.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: IconPalette.testo,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '€${e.budget.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: IconPalette.testo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                          if (goal != null) ...[
                            const SizedBox(height: 12),
                            DelayedEntrance(
                              delay: Duration(
                                milliseconds:
                                    900 + envelopes.length * 130,
                              ),
                              child: DemoCard(
                                color: IconPalette.sfondoAlt,
                                child: Row(
                                  children: [
                                    const Text(
                                      '🎯',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${goal.title}: €${goal.targetAmount.toStringAsFixed(0)} '
                                        'di obiettivo',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: IconPalette.testo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          DelayedEntrance(
                            delay: Duration(
                              milliseconds: 1100 + envelopes.length * 130,
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Il tuo budget è pronto.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: IconPalette.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: IconPalette.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _finishing ? null : _finish,
                                    child: _finishing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'INIZIA',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
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
              },
            );
          },
        ),
      ),
    );
  }
}
