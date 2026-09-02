/// Spesa fissa ricorrente definita dall'utente (es. "Mutuo, €700, ogni mese
/// il giorno 5"). Non genera mai da sola una spesa reale: [lastGeneratedMonthKey]
/// serve solo a sapere se è già stata confermata questo mese, la scrittura
/// vera avviene sempre tramite FirestoreService.confirmRecurringExpense,
/// chiamata solo dopo un tap esplicito dell'utente sul promemoria in Home.
class RecurringExpense {
  final String id;
  final String description;
  final double amount;
  final String envelopeId;

  /// Giorno del mese in cui la spesa è dovuta (1-28, per evitare mesi che
  /// non hanno il giorno 29/30/31).
  final int dayOfMonth;
  final bool active;

  /// "yyyy-MM" dell'ultimo mese in cui l'utente ha confermato la
  /// registrazione, null se non ancora confermata per nessun mese.
  final String? lastGeneratedMonthKey;

  RecurringExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.envelopeId,
    required this.dayOfMonth,
    this.active = true,
    this.lastGeneratedMonthKey,
  });

  factory RecurringExpense.fromMap(String id, Map<String, dynamic> data) {
    return RecurringExpense(
      id: id,
      description: data['description'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      envelopeId: data['envelopeId'] ?? '',
      dayOfMonth: (data['dayOfMonth'] as num).toInt(),
      active: data['active'] ?? true,
      lastGeneratedMonthKey: data['lastGeneratedMonthKey'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'envelopeId': envelopeId,
      'dayOfMonth': dayOfMonth,
      'active': active,
      'lastGeneratedMonthKey': lastGeneratedMonthKey,
    };
  }

  /// Dovuta se attiva, non ancora confermata per il mese corrente e siamo
  /// arrivati al giorno stabilito (o oltre — es. utente che apre l'app in
  /// ritardo rispetto al giorno previsto).
  bool isDueOn(DateTime now) {
    if (!active) return false;
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (lastGeneratedMonthKey == monthKey) return false;
    return now.day >= dayOfMonth;
  }
}
