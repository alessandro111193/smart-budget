import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/screens/onboarding/setup/setup_envelopes_step.dart';

void main() {
  group('suggestedEnvelopeBudgets somma sempre esattamente all\'entrata', () {
    test('famiglia di 4, entrata €1.500 (scenario del bug segnalato)', () {
      final budgets = suggestedEnvelopeBudgets(1500, 4);
      final sum = budgets.fold<double>(0, (a, b) => a + b);
      expect(sum, 1500);
      expect(budgets.length, 7);
    });

    test('persona singola: nessuno scaling, deve continuare a funzionare', () {
      final budgets = suggestedEnvelopeBudgets(1500, 1);
      final sum = budgets.fold<double>(0, (a, b) => a + b);
      expect(sum, 1500);
    });

    test('famiglia di 8 (massimo stepper): la normalizzazione regge anche al limite', () {
      final budgets = suggestedEnvelopeBudgets(1500, 8);
      final sum = budgets.fold<double>(0, (a, b) => a + b);
      expect(sum, 1500);
    });

    test('entrata non intera e famiglia numerosa', () {
      final budgets = suggestedEnvelopeBudgets(2137, 6);
      final sum = budgets.fold<double>(0, (a, b) => a + b);
      expect(sum, 2137);
    });

    test('entrata 0 (utente ha saltato il passaggio): usa il default demo 2400', () {
      final budgets = suggestedEnvelopeBudgets(0, 4);
      final sum = budgets.fold<double>(0, (a, b) => a + b);
      expect(sum, 2400);
    });
  });
}
