import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/income.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../models/envelope.dart';
import '../models/expense.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference get _envelopes =>
      _db.collection('users').doc(userId).collection('envelopes');

  Stream<List<Envelope>> streamEnvelopes() {
    return _envelopes.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => Envelope(
              id: doc.id,
              name: doc['name'],
              category: doc['category'],
              budget: (doc['budget'] as num).toDouble(),
              balance: (doc['balance'] as num).toDouble(),
              icon: doc['icon'],
            ),
          )
          .toList(),
    );
  }

  Future<void> addEnvelope(Envelope e) {
    return _envelopes.add({
      'name': e.name,
      'category': e.category,
      'budget': e.budget,
      'balance': e.balance,
      'icon': e.icon,
    });
  }

  Future<void> updateEnvelopeBalance(String envelopeId, double newBalance) {
    return _envelopes.doc(envelopeId).update({'balance': newBalance});
  }

  Future<void> deleteEnvelope(String envelopeId) {
    return _envelopes.doc(envelopeId).delete();
  }

  CollectionReference get _expenses =>
      _db.collection('users').doc(userId).collection('expenses');

  Future<void> addExpense(Expense exp) async {
    await _expenses.add({
      'amount': exp.amount,
      'category': exp.category,
      'envelopeId': exp.envelopeId,
      'description': exp.description,
      'date': exp.date.toIso8601String(),
    });

    final envelopeDoc = await _envelopes.doc(exp.envelopeId).get();
    final currentBalance = (envelopeDoc['balance'] as num).toDouble();
    await updateEnvelopeBalance(exp.envelopeId, currentBalance - exp.amount);
  }

  Stream<List<Income>> streamIncomes() {
    return _db
        .collection('users')
        .doc(userId)
        .collection('incomes')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Income.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Expense>> streamExpenses() {
    return _expenses.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => Expense(
              id: doc.id,
              amount: (doc['amount'] as num).toDouble(),
              category: doc['category'],
              envelopeId: doc['envelopeId'],
              description: doc['description'],
              date: DateTime.parse(doc['date']),
            ),
          )
          .toList(),
    );
  }

  CollectionReference get _challenges =>
      _db.collection('users').doc(userId).collection('challenges');

  Stream<List<Challenge>> streamChallenges() {
    return _challenges.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => Challenge(
              id: doc.id,
              title: doc['title'],
              type: ChallengeType.values[doc['type']],
              targetAmount: (doc['targetAmount'] as num).toDouble(),
              savedAmount: (doc['savedAmount'] as num).toDouble(),
              deadline: doc['deadline'] != null
                  ? DateTime.parse(doc['deadline'])
                  : null,
            ),
          )
          .toList(),
    );
  }

  Future<void> addChallenge(Challenge c) {
    return _challenges.add({
      'title': c.title,
      'type': c.type.index,
      'targetAmount': c.targetAmount,
      'savedAmount': c.savedAmount,
      'deadline': c.deadline?.toIso8601String(),
    });
  }

  Future<void> addToChallenge(String challengeId, double amount) async {
    final doc = await _challenges.doc(challengeId).get();
    final current = (doc['savedAmount'] as num).toDouble();
    await _challenges.doc(challengeId).update({
      'savedAmount': current + amount,
    });
  }

  DocumentReference get _userDoc => _db.collection('users').doc(userId);

  Stream<AppUser> streamUser() {
    return _userDoc.snapshots().map((doc) {
      if (!doc.exists) {
        return AppUser(
          isPremium: false,
          isTrialActive: false,
          scontriniUsati: 0,
          richiesteAiUsate: 0,
          analisiAvanzateUsate: 0,
        );
      }
      final data = doc.data() as Map<String, dynamic>;
      final trialEndStr = data['trialEnd'] as String?;
      final trialEnd = trialEndStr != null ? DateTime.parse(trialEndStr) : null;
      final trialActive = trialEnd != null && trialEnd.isAfter(DateTime.now());
      return AppUser(
        isPremium: data['isPremium'] ?? false,
        isTrialActive: trialActive,
        trialEnd: trialEnd,
        scontriniUsati: data['scontriniUsati'] ?? 0,
        richiesteAiUsate: data['richiesteAiUsate'] ?? 0,
        analisiAvanzateUsate: data['analisiAvanzateUsate'] ?? 0,
      );
    });
  }

  Future<void> startTrial() {
    final trialEnd = DateTime.now().add(const Duration(days: 15));
    return _userDoc.set({
      'isPremium': false,
      'trialEnd': trialEnd.toIso8601String(),
      'scontriniUsati': 0,
      'richiesteAiUsate': 0,
      'analisiAvanzateUsate': 0,
    }, SetOptions(merge: true));
  }

  double totalBudget(List<Envelope> envelopes) =>
      envelopes.fold(0, (s, e) => s + e.budget);

  double totalDisponibile(List<Envelope> envelopes) =>
      envelopes.fold(0, (s, e) => s + e.balance);

  double totalSpeso(List<Envelope> envelopes) =>
      totalBudget(envelopes) - totalDisponibile(envelopes);

  Future<void> distributeIncome(
    Map<String, double> allocationByEnvelopeId,
  ) async {
    for (final entry in allocationByEnvelopeId.entries) {
      if (entry.value <= 0) continue;
      final doc = await _envelopes.doc(entry.key).get();
      final current = (doc['balance'] as num).toDouble();
      await updateEnvelopeBalance(entry.key, current + entry.value);
    }
  }

  Future<void> addIncome({
    required String description,
    required double amount,
    required String category, // Parametro categoria aggiunto
    required Map<String, double> allocations,
  }) async {
    await _db.collection('users').doc(userId).collection('incomes').add({
      'description': description,
      'amount': amount,
      'category': category, // Salvato correttamente su Firestore
      'date': DateTime.now().toIso8601String(),
      'allocations': allocations,
    });

    for (final entry in allocations.entries) {
      if (entry.value <= 0) continue;
      final doc = await _envelopes.doc(entry.key).get();
      if (doc.exists) {
        final current = (doc['balance'] as num).toDouble();
        await updateEnvelopeBalance(entry.key, current + entry.value);
      }
    }
  }
}
