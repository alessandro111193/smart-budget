import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/envelope.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
import '../models/family_income.dart';
import 'analytics_service.dart';

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

  // Blocco C (Famiglia come funzione Premium): non più una scrittura
  // diretta su Firestore (firestore.rules blocca "allow create: if false"
  // sui client) — passa dalla Cloud Function createFamily, che verifica
  // Premium/Trial attivo lato server prima di creare qualunque documento.
  Future<String> createFamily(String name) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('createFamily')
        .call({'name': name});
    final familyId = result.data['familyId'] as String;
    AnalyticsService.logFamilyCreated();
    return familyId;
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
    AnalyticsService.logFamilyMemberInvited();
    return result.data['message'] as String;
  }

  /// Inviti pendenti per l'email dell'utente corrente, cercati fra tutte le famiglie
  Stream<List<Map<String, dynamic>>> streamMyPendingInvites() {
    if (userId.isEmpty) return const Stream.empty();
    // Confronto sull'uid, non sull'email: è l'unica forma che Firestore può
    // "dimostrare" per una query collectionGroup (vedi commento sulla stessa
    // logica in functions/index.js, inviteFamilyMember) — un confronto su
    // resource.data.email, anche già normalizzato in minuscolo, veniva
    // rifiutato in blocco con permission-denied indipendentemente dai dati,
    // perché la regola precedente lo combinava in OR con isOwner() (un
    // get() su un segmento di path variabile, non provabile per una list()).
    return _db
        .collectionGroup('invites')
        .where('invitedUid', isEqualTo: userId)
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

  /// Rimuove un membro dalla famiglia — solo l'owner può farlo (verificato
  /// anche lato server dalla Cloud Function, non solo nascosto in UI).
  Future<String> removeMember(String familyId, String memberId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'removeFamilyMember',
    );
    final result = await callable.call({
      'familyId': familyId,
      'memberId': memberId,
    });
    return result.data['message'] as String;
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

  Future<String> addFamilyEnvelope(String familyId, Envelope e) async {
    final doc = await _familyEnvelopes(familyId).add({
      'name': e.name,
      'category': e.category,
      'budget': e.budget,
      'balance': e.balance,
      'icon': e.icon,
    });
    AnalyticsService.logEnvelopeCreated(isFamily: true);
    return doc.id;
  }

  /// Stesso comportamento di FirestoreService.updateEnvelope: il saldo
  /// viene spostato della differenza di budget, così "quanto è già stato
  /// speso" resta invariato dopo la modifica.
  Future<void> updateFamilyEnvelope(
    String familyId,
    String envelopeId, {
    required String name,
    required String category,
    required double budget,
    required String icon,
    required double budgetDelta,
  }) {
    return _familyEnvelopes(familyId).doc(envelopeId).update({
      'name': name,
      'category': category,
      'budget': budget,
      'icon': icon,
      'balance': FieldValue.increment(budgetDelta),
    });
  }

  Future<void> deleteFamilyEnvelope(String familyId, String envelopeId) {
    return _familyEnvelopes(familyId).doc(envelopeId).delete();
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
    AnalyticsService.logExpenseAdded(isFamily: true);
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

  /// Batch atomico con FieldValue.increment (stesso motivo di
  /// FirestoreService.addIncome): più membri della famiglia possono
  /// scrivere sulle stesse buste condivise quasi contemporaneamente, quindi
  /// niente letture separate del saldo prima di scriverlo.
  Future<void> addFamilyIncome({
    required String familyId,
    required double amount,
    required String description,
    String? memberId,
    required Map<String, double> allocations,
  }) async {
    final batch = _db.batch();
    batch.set(_familyIncomes(familyId).doc(), {
      'amount': amount,
      'description': description,
      'date': DateTime.now().toIso8601String(),
      'memberId': memberId,
      'allocations': allocations,
    });
    for (final entry in allocations.entries) {
      if (entry.value <= 0) continue;
      batch.update(_familyEnvelopes(familyId).doc(entry.key), {
        'balance': FieldValue.increment(entry.value),
      });
    }
    await batch.commit();
    AnalyticsService.logIncomeAdded(isFamily: true);
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

  /// Totale entrate famiglia (tutte, incluse quelle non attribuite a un
  /// membro specifico)
  double familyTotalIncomes(List<FamilyIncome> incomes) =>
      incomes.fold(0, (s, i) => s + i.amount);

  /// Entrate registrate a nome di un membro specifico (non include le
  /// entrate del nucleo senza memberId)
  double memberIncomeTotal(List<FamilyIncome> incomes, String memberId) =>
      incomes
          .where((i) => i.memberId == memberId)
          .fold(0, (s, i) => s + i.amount);
}
