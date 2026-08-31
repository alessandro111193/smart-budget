class FamilyIncome {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final String? memberId; // null = entrata del nucleo, non di un singolo

  FamilyIncome({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    this.memberId,
  });

  factory FamilyIncome.fromMap(String id, Map<String, dynamic> data) {
    return FamilyIncome(
      id: id,
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] ?? '',
      date: DateTime.parse(data['date']),
      memberId: data['memberId'],
    );
  }
}
