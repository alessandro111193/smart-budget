class FamilyIncome {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final String? memberId; // null = entrata del nucleo, non di un singolo
  final Map<String, double> allocations; // envelopeId -> importo assegnato

  FamilyIncome({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    this.memberId,
    this.allocations = const {},
  });

  factory FamilyIncome.fromMap(String id, Map<String, dynamic> data) {
    final rawAllocations = data['allocations'] as Map<dynamic, dynamic>?;
    return FamilyIncome(
      id: id,
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] ?? '',
      date: DateTime.parse(data['date']),
      memberId: data['memberId'],
      allocations:
          rawAllocations?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ) ??
          const {},
    );
  }
}
