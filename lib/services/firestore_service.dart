import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/income.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../models/envelope.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import 'analytics_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference get _envelopes =>
      _db.collection('users').doc(userId).collection('envelopes');

  Stream<List<Envelope>> streamEnvelopes() {
    return _envelopes.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Envelope(
          id: doc.id,
          name: data['name'],
          category: data['category'],
          budget: (data['budget'] as num).toDouble(),
          balance: (data['balance'] as num).toDouble(),
          icon: data['icon'],
          isGeneral: data['isGeneral'] == true,
        );
      }).toList(),
    );
  }

  /// Restituisce l'id della busta "Spese generali" (la crea se non esiste
  /// ancora, al più una per utente). Usata quando l'utente registra una
  /// spesa senza scegliere una busta propria: nessun budget reale (budget
  /// e balance partono da 0, il balance può scendere sotto zero man mano
  /// che si spende — è lo stesso FieldValue.increment già usato per ogni
  /// altra busta in addExpense), così da restare comunque un envelopeId
  /// reale e non richiedere nessun caso speciale altrove nell'app
  /// (statistiche, alert budget — questi ultimi già ignorano le buste con
  /// budget <= 0).
  Future<String> ensureGeneralEnvelope() async {
    final existing = await _envelopes
        .where('isGeneral', isEqualTo: true)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    return addEnvelope(
      Envelope(
        id: '',
        name: 'Spese generali',
        category: 'Spese generali',
        budget: 0,
        balance: 0,
        icon: '📦',
        isGeneral: true,
      ),
    );
  }

  Future<String> addEnvelope(Envelope e) async {
    final doc = await _envelopes.add({
      'name': e.name,
      'category': e.category,
      'budget': e.budget,
      'balance': e.balance,
      'icon': e.icon,
      'isGeneral': e.isGeneral,
    });
    AnalyticsService.logEnvelopeCreated(isFamily: false);
    return doc.id;
  }

  Future<void> deleteEnvelope(String envelopeId) {
    return _envelopes.doc(envelopeId).delete();
  }

  /// Aggiorna nome/categoria/budget/icona di una busta esistente. [budget]
  /// è il nuovo importo totale; il saldo disponibile viene spostato della
  /// stessa differenza (budgetDelta = nuovo - vecchio) così che "quanto è
  /// già stato speso" (budget - saldo) resti invariato dopo la modifica —
  /// altrimenti aumentare il budget farebbe apparire come "spesa" la
  /// differenza, e diminuirlo la farebbe sparire.
  Future<void> updateEnvelope(
    String envelopeId, {
    required String name,
    required String category,
    required double budget,
    required String icon,
    required double budgetDelta,
  }) {
    return _envelopes.doc(envelopeId).update({
      'name': name,
      'category': category,
      'budget': budget,
      'icon': icon,
      'balance': FieldValue.increment(budgetDelta),
    });
  }

  CollectionReference get _expenses =>
      _db.collection('users').doc(userId).collection('expenses');

  /// Registra la spesa e scala il saldo busta in un'unica scrittura atomica
  /// (batch con FieldValue.increment, nessuna lettura preventiva del saldo
  /// necessaria): evita che due spese quasi simultanee sulla stessa busta
  /// si "perdano" a vicenda, come già garantito lato famiglia da
  /// FamilyService.addFamilyExpense.
  Future<void> addExpense(Expense exp) async {
    final batch = _db.batch();
    batch.set(_expenses.doc(), {
      'amount': exp.amount,
      'category': exp.category,
      'envelopeId': exp.envelopeId,
      'description': exp.description,
      'date': exp.date.toIso8601String(),
    });
    batch.update(_envelopes.doc(exp.envelopeId), {
      'balance': FieldValue.increment(-exp.amount),
    });
    await batch.commit();
    AnalyticsService.logExpenseAdded(isFamily: false);
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

  CollectionReference get _recurringExpenses =>
      _db.collection('users').doc(userId).collection('recurringExpenses');

  Stream<List<RecurringExpense>> streamRecurringExpenses() {
    return _recurringExpenses.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => RecurringExpense.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Future<void> addRecurringExpense(RecurringExpense r) {
    return _recurringExpenses.add(r.toMap());
  }

  Future<void> updateRecurringExpense(RecurringExpense r) {
    return _recurringExpenses.doc(r.id).update(r.toMap());
  }

  Future<void> deleteRecurringExpense(String id) {
    return _recurringExpenses.doc(id).delete();
  }

  /// Unico punto in cui una spesa ricorrente diventa una spesa reale:
  /// chiamato SOLO dopo un tap esplicito dell'utente sul promemoria in
  /// Home, mai automaticamente. Riusa addExpense (stessa scrittura atomica
  /// spesa+decremento saldo busta) e poi segna il mese corrente come già
  /// confermato, così il promemoria non ricompare fino al mese prossimo.
  Future<void> confirmRecurringExpense(RecurringExpense r) async {
    await addExpense(
      Expense(
        id: '',
        amount: r.amount,
        category: r.description,
        envelopeId: r.envelopeId,
        description: r.description,
        date: DateTime.now(),
      ),
    );
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await _recurringExpenses.doc(r.id).update({
      'lastGeneratedMonthKey': monthKey,
    });
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

  /// FieldValue.increment è atomico lato server: due contributi ravvicinati
  /// alla stessa challenge (es. doppio tap, o due dispositivi) non si
  /// perdono più a vicenda come con il precedente leggi-poi-scrivi.
  Future<void> addToChallenge(String challengeId, double amount) {
    return _challenges.doc(challengeId).update({
      'savedAmount': FieldValue.increment(amount),
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
        playPurchaseToken: data['playPurchaseToken'] as String?,
        playProductId: data['playProductId'] as String?,
      );
    });
  }

  // isPremium/trialEnd/contatori non sono più scrivibili dal client
  // (Firestore Rules): l'attivazione passa dalla Cloud Function startTrial,
  // che scrive questi campi via Admin SDK con lo stesso comportamento di
  // prima (15 giorni, contatori azzerati).
  Future<void> startTrial() async {
    await FirebaseFunctions.instance.httpsCallable('startTrial').call();
    AnalyticsService.logTrialStarted();
  }

  /// Vero solo per un account appena creato dal wizard di configurazione
  /// dell'onboarding (`setupCompleted: false` scritto da `login_screen.dart`
  /// al momento della registrazione) finché non arriva a fine wizard.
  /// Un account esistente, o creato prima di questa funzionalità, non ha
  /// questo campo: il default `true` lo fa andare dritto alla Home reale,
  /// senza rivedere il wizard.
  Stream<bool> streamSetupCompleted() {
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return (data?['setupCompleted'] as bool?) ?? true;
    });
  }

  Future<void> markSetupCompleted() {
    return _userDoc.set({'setupCompleted': true}, SetOptions(merge: true));
  }

  double totalBudget(List<Envelope> envelopes) =>
      envelopes.fold(0, (s, e) => s + e.budget);

  double totalDisponibile(List<Envelope> envelopes) =>
      envelopes.fold(0, (s, e) => s + e.balance);

  double totalSpeso(List<Envelope> envelopes) =>
      totalBudget(envelopes) - totalDisponibile(envelopes);

  /// Batch atomico con FieldValue.increment: nessuna lettura preventiva del
  /// saldo, quindi nessun rischio che due distribuzioni quasi simultanee
  /// sulla stessa busta si sovrascrivano a vicenda.
  Future<void> distributeIncome(
    Map<String, double> allocationByEnvelopeId,
  ) async {
    final entries = allocationByEnvelopeId.entries.where((e) => e.value > 0);
    if (entries.isEmpty) return;
    final batch = _db.batch();
    for (final entry in entries) {
      batch.update(_envelopes.doc(entry.key), {
        'balance': FieldValue.increment(entry.value),
      });
    }
    await batch.commit();
  }

  /// Stesso motivo di [addExpense]/[distributeIncome]: la registrazione
  /// dell'entrata e l'aggiornamento dei saldi busta sono un unico batch
  /// atomico, mai più letture separate del saldo corrente.
  Future<void> addIncome({
    required String description,
    required double amount,
    required String category,
    required Map<String, double> allocations,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(userId).collection('incomes').doc(),
      {
        'description': description,
        'amount': amount,
        'category': category,
        'date': DateTime.now().toIso8601String(),
        'allocations': allocations,
      },
    );
    for (final entry in allocations.entries) {
      if (entry.value <= 0) continue;
      batch.update(_envelopes.doc(entry.key), {
        'balance': FieldValue.increment(entry.value),
      });
    }
    await batch.commit();
    AnalyticsService.logIncomeAdded(isFamily: false);
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
