import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/models/challenge.dart';
import 'package:smart_budget/models/envelope.dart';
import 'package:smart_budget/models/expense.dart';
import 'package:smart_budget/services/budget_insights.dart';

void main() {
  group('Challenge.projectedCompletionDate', () {
    test('proietta una data quando c\'è un ritmo di risparmio reale', () {
      final challenge = Challenge(
        id: '1',
        title: 'Vacanza',
        type: ChallengeType.saving,
        targetAmount: 1000,
        savedAmount: 100,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      // Ritmo: 10€/giorno, mancano 900€ -> ~90 giorni da oggi.
      expect(challenge.projectedCompletionDate, isNotNull);
      final daysFromNow = challenge.projectedCompletionDate!
          .difference(DateTime.now())
          .inDays;
      expect(daysFromNow, greaterThan(85));
      expect(daysFromNow, lessThan(95));
    });

    test('null se sono passati troppo pochi giorni dalla creazione', () {
      final challenge = Challenge(
        id: '1',
        title: 'Vacanza',
        type: ChallengeType.saving,
        targetAmount: 1000,
        savedAmount: 500,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(challenge.projectedCompletionDate, isNull);
    });

    test('null se non è stato ancora risparmiato nulla', () {
      final challenge = Challenge(
        id: '1',
        title: 'Vacanza',
        type: ChallengeType.saving,
        targetAmount: 1000,
        savedAmount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(challenge.projectedCompletionDate, isNull);
    });

    test('già raggiunto restituisce la data odierna', () {
      final challenge = Challenge(
        id: '1',
        title: 'Vacanza',
        type: ChallengeType.saving,
        targetAmount: 1000,
        savedAmount: 1200,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      final projected = challenge.projectedCompletionDate!;
      expect(projected.difference(DateTime.now()).inMinutes.abs(), lessThan(2));
    });

    test('null per un tetto di spesa (non è un obiettivo di risparmio)', () {
      final challenge = Challenge(
        id: '1',
        title: 'Tetto svago',
        type: ChallengeType.spendingLimit,
        targetAmount: 200,
        savedAmount: 50,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(challenge.projectedCompletionDate, isNull);
    });
  });

  group('BudgetInsights — data stimata di esaurimento busta', () {
    test('include il giorno stimato quando cade entro il mese corrente', () {
      final now = DateTime(2026, 9, 10);
      final envelope = Envelope(
        id: 'e1',
        name: 'Spesa',
        category: 'Spesa',
        budget: 300,
        balance: 50,
        icon: '🛒',
      );
      // Speso 180€ in 10 giorni -> 18€/giorno. Con 50€ residui, si esaurisce
      // in circa 3 giorni -> giorno 13 del mese, entro settembre (30 giorni).
      final expenses = [
        Expense(
          id: 'x1',
          amount: 180,
          category: 'Spesa',
          envelopeId: 'e1',
          description: 'Spesa',
          date: DateTime(2026, 9, 5),
        ),
      ];
      final alerts = BudgetInsights.compute(
        envelopes: [envelope],
        expenses: expenses,
        now: now,
      );
      final match = alerts.where((a) => a.message.contains('Spesa'));
      expect(match, isNotEmpty);
      expect(
        match.any((a) => a.message.contains('intorno al 13 del mese')),
        isTrue,
        reason: 'Messaggio effettivo: ${match.map((a) => a.message).join(' | ')}',
      );
    });
  });
}
