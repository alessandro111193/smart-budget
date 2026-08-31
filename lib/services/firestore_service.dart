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

  Future<String> addEnvelope(Envelope e) async {
    final doc = await _envelopes.add({
      'name': e.name,
      'category': e.category,
      'budget': e.budget,
      'balance': e.balance,
      'icon': e.icon,
    });
    return doc.id;
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
      (snapshot) =>
          snapshot.docs.map((doc) => Challenge.fromFirestore(doc)).toList(),
    );
  }

  Future<void> addChallenge(Challenge c) {
    return _challenges.add(c.toMap());
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
    required String category,
    required Map<String, double> allocations,
  }) async {
    await _db.collection('users').doc(userId).collection('incomes').add({
      'description': description,
      'amount': amount,
      'category': category,
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

  // Stato della lista della spesa intelligente. Salvato sul documento
  // utente esistente (già coperto dalle Firestore Rules attuali) invece
  // di una nuova sottocollezione, per non dover modificare le regole.
  Stream<ShoppingListState> streamShoppingListState() {
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return ShoppingListState(
        checked: List<String>.from(data['shoppingListChecked'] ?? []),
        manualItems: List<String>.from(data['shoppingListManualItems'] ?? []),
      );
    });
  }

  Future<void> setShoppingListItemChecked(String key, bool checked) {
    return _userDoc.set({
      'shoppingListChecked': checked
          ? FieldValue.arrayUnion([key])
          : FieldValue.arrayRemove([key]),
    }, SetOptions(merge: true));
  }

  Future<void> addManualShoppingItem(String name) {
    return _userDoc.set({
      'shoppingListManualItems': FieldValue.arrayUnion([name]),
    }, SetOptions(merge: true));
  }

  Future<void> removeManualShoppingItem(String name) {
    return _userDoc.set({
      'shoppingListManualItems': FieldValue.arrayRemove([name]),
      'shoppingListChecked': FieldValue.arrayRemove([name]),
    }, SetOptions(merge: true));
  }

  Future<void> clearShoppingListChecks() {
    return _userDoc.set({
      'shoppingListChecked': <String>[],
    }, SetOptions(merge: true));
  }

  // Cache dei contenuti AI proattivi (Consiglio del giorno / Report
  // mensile), scritta dalla Cloud Function generateAiInsight. Anche questi
  // sono campi sul documento utente esistente, stesso motivo dello stato
  // della lista della spesa: zero modifiche alle Firestore Rules.
  Stream<AiDailyTip?> streamAiDailyTip() {
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final raw = data['aiDailyTip'] as Map<String, dynamic>?;
      if (raw == null) return null;
      return AiDailyTip(
        text: raw['text'] as String? ?? '',
        dateKey: raw['dateKey'] as String? ?? '',
      );
    });
  }

  Stream<AiMonthlyReport?> streamAiMonthlyReport() {
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final raw = data['aiMonthlyReport'] as Map<String, dynamic>?;
      if (raw == null) return null;
      return AiMonthlyReport(
        monthKey: raw['monthKey'] as String? ?? '',
        puntoDiForza: raw['puntoDiForza'] as String? ?? '',
        attenzione: raw['attenzione'] as String? ?? '',
        consiglio: raw['consiglio'] as String? ?? '',
        totalEntrate: (raw['totalEntrate'] as num?)?.toDouble() ?? 0,
        totalSpeso: (raw['totalSpeso'] as num?)?.toDouble() ?? 0,
      );
    });
  }
}

class ShoppingListState {
  final List<String> checked;
  final List<String> manualItems;

  ShoppingListState({required this.checked, required this.manualItems});
}

class AiDailyTip {
  final String text;
  final String dateKey;

  AiDailyTip({required this.text, required this.dateKey});
}

class AiMonthlyReport {
  final String monthKey;
  final String puntoDiForza;
  final String attenzione;
  final String consiglio;
  final double totalEntrate;
  final double totalSpeso;

  AiMonthlyReport({
    required this.monthKey,
    required this.puntoDiForza,
    required this.attenzione,
    required this.consiglio,
    required this.totalEntrate,
    required this.totalSpeso,
  });

  double get risparmio => totalEntrate - totalSpeso;
}
