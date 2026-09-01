import 'package:flutter/material.dart';

import 'setup_envelopes_step.dart';
import 'setup_goal_step.dart';
import 'setup_income_step.dart';
import 'setup_name_step.dart';
import 'setup_transform_screen.dart';

enum _SetupStep { name, income, envelopes, goal, transform }

/// Configurazione reale guidata, mostrata solo agli account appena creati
/// (vedi `FirestoreService.streamSetupCompleted`). Ogni passaggio salva
/// davvero i dati con i servizi già esistenti (`FirestoreService`) — non
/// è una demo. Passaggi in avanti soltanto: non c'è "indietro" tra un
/// passaggio e l'altro perché ognuno scrive già su Firestore, tornare
/// indietro richiederebbe disfare scritture reali (creare quella
/// possibilità non è stato chiesto esplicitamente ed è un rischio in più
/// non necessario).
class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  _SetupStep _step = _SetupStep.name;

  /// Entrata mensile inserita al passaggio precedente, usata per
  /// proporzionare i budget suggeriti delle buste (0 se saltata).
  double _monthlyIncome = 0;

  void _goTo(_SetupStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_step) {
        _SetupStep.name => SetupNameStep(
          key: const ValueKey('name'),
          onNext: () => _goTo(_SetupStep.income),
        ),
        _SetupStep.income => SetupIncomeStep(
          key: const ValueKey('income'),
          onNext: (amount) {
            _monthlyIncome = amount;
            _goTo(_SetupStep.envelopes);
          },
        ),
        _SetupStep.envelopes => SetupEnvelopesStep(
          key: const ValueKey('envelopes'),
          monthlyIncome: _monthlyIncome,
          onNext: () => _goTo(_SetupStep.goal),
        ),
        _SetupStep.goal => SetupGoalStep(
          key: const ValueKey('goal'),
          onNext: () => _goTo(_SetupStep.transform),
        ),
        _SetupStep.transform => const SetupTransformScreen(
          key: ValueKey('transform'),
        ),
      },
    );
  }
}
