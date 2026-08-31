import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/envelope.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
import '../models/family_income.dart';

class FamilyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String? get userEmail => FirebaseAuth.instance.currentUser?.email;

  /// Il familyId dell'utente corrente (null se non fa parte di nessuna famiglia)
  Stream<String?> streamMyFamilyId() {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? (doc.data()?['familyId'] as String?) : null);
  }

  Future<String> createFamily(String name) async {
    final familyRef = _db.collection('families').doc();
    await familyRef.set({
      'name': name,
      'ownerId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await familyRef.collection('members').doc(userId).set({
      'name': FirebaseAuth.instance.currentUser?.displayName ?? 'Io',
      'role': 'owner',
      'colorTag': '#16B98C',
      'joinedAt': DateTime.now().toIso8601String(),
    });
    await _db.collection('users').doc(userId).set({
      'familyId': familyRef.id,
    }, SetOptions(merge: true));
    return familyRef.id;
  }

  Stream<Family?> streamFamily(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .snapshots()
        .map((doc) => doc.exists ? Family.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<FamilyMember>> streamMembers(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .collection('members')
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => FamilyMember.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<FamilyInvite>> streamInvites(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .collection('invites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => FamilyInvite.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Invita tramite email — passa dalla Cloud Function, non crea l'utente a mano
  Future<String> inviteMember(String familyId, String email) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'inviteFamilyMember',
    );
    final result = await callable.call({'familyId': familyId, 'email': email});
    return result.data['message'] as String;
  }

  /// Inviti pendenti per l'email dell'utente corrente, cercati fra tutte le famiglie
  Stream<List<Map<String, dynamic>>> streamMyPendingInvites() {
    if (userEmail == null) return const Stream.empty();
    return _db
        .collectionGroup('invites')
        .where('email', isEqualTo: userEmail)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => {
                  'inviteId': d.id,
                  'familyId': d.reference.parent.parent!.id,
                  ...d.data(),
                },
              )
              .toList(),
        );
  }

  Future<void> acceptInvite(String familyId, String inviteId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'acceptFamilyInvite',
    );
    await callable.call({'familyId': familyId, 'inviteId': inviteId});
  }

  CollectionReference _familyEnvelopes(String familyId) =>
      _db.collection('families').doc(familyId).collection('envelopes');

  CollectionReference _familyExpenses(String familyId) =>
      _db.collection('families').doc(familyId).collection('expenses');

  CollectionReference _familyIncomes(String familyId) =>
      _db.collection('families').doc(familyId).collection('incomes');

  Stream<List<Envelope>> streamFamilyEnvelopes(String familyId) {
    return _familyEnvelopes(familyId).snapshots().map(
      (s) => s.docs
          .map(
            (d) => Envelope(
              id: d.id,
              name: d['name'],
              category: d['category'],
              budget: (d['budget'] as num).toDouble(),
              balance: (d['balance'] as num).toDouble(),
              icon: d['icon'],
            ),
          )
          .toList(),
    );
  }

  Future<void> addFamilyEnvelope(String familyId, Envelope e) {
    return _familyEnvelopes(familyId).add({
      'name': e.name,
      'category': e.category,
      'budget': e.budget,
      'balance': e.balance,
      'icon': e.icon,
    });
  }

  Stream<List<FamilyExpense>> streamFamilyExpenses(String familyId) {
    return _familyExpenses(familyId).snapshots().map(
      (s) => s.docs
          .map(
            (d) =>
                FamilyExpense.fromMap(d.id, d.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Aggiunge la spesa E aggiorna il saldo busta in un'unica transazione:
  /// evita che due spese scritte quasi insieme "si perdano" a vicenda.
  Future<void> addFamilyExpense(String familyId, FamilyExpense exp) async {
    final envelopeRef = _familyEnvelopes(familyId).doc(exp.envelopeId);
    final expenseRef = _familyExpenses(familyId).doc();

    await _db.runTransaction((transaction) async {
      final envelopeSnap = await transaction.get(envelopeRef);
      final currentBalance = (envelopeSnap['balance'] as num).toDouble();
      transaction.set(expenseRef, exp.toMap());
      transaction.update(envelopeRef, {'balance': currentBalance - exp.amount});
    });
  }

  Stream<List<FamilyIncome>> streamFamilyIncomes(String familyId) {
    return _familyIncomes(familyId).snapshots().map(
      (s) => s.docs
          .map(
            (d) => FamilyIncome.fromMap(d.id, d.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<void> addFamilyIncome({
    required String familyId,
    required double amount,
    required String description,
    String? memberId,
    required Map<String, double> allocations,
  }) async {
    await _familyIncomes(familyId).add({
      'amount': amount,
      'description': description,
      'date': DateTime.now().toIso8601String(),
      'memberId': memberId,
    });
    for (final entry in allocations.entries) {
      if (entry.value <= 0) continue;
      final envRef = _familyEnvelopes(familyId).doc(entry.key);
      final doc = await envRef.get();
      if (doc.exists) {
        final current = (doc['balance'] as num).toDouble();
        await envRef.update({'balance': current + entry.value});
      }
    }
  }

  /// Totale famiglia: somma di 'amount', una volta sola per spesa — mai doppio conteggio
  double familyTotalExpenses(List<FamilyExpense> expenses) =>
      expenses.fold(0, (s, e) => s + e.amount);

  /// Quota di un membro specifico su tutte le spese familiari
  double memberExpenseTotal(
    List<FamilyExpense> expenses,
    String memberId,
    int totalMembersCount,
  ) {
    return expenses.fold(
      0,
      (s, e) => s + e.quotaFor(memberId, totalMembersCount),
    );
  }
}
