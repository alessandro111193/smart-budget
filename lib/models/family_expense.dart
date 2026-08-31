enum FamilyExpenseType { personal, shared, split }

class FamilyExpense {
  final String id;
  final double amount;
  final String description;
  final String envelopeId;
  final DateTime date;
  final FamilyExpenseType type;
  final String? memberId; // usato solo per "personal"
  final Map<String, double>? splitAllocations; // usato solo per "split"

  FamilyExpense({
    required this.id,
    required this.amount,
    required this.description,
    required this.envelopeId,
    required this.date,
    required this.type,
    this.memberId,
    this.splitAllocations,
  });

  factory FamilyExpense.fromMap(String id, Map<String, dynamic> data) {
    final rawSplit = data['splitAllocations'] as Map<dynamic, dynamic>?;
    return FamilyExpense(
      id: id,
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] ?? '',
      envelopeId: data['envelopeId'] ?? '',
      date: DateTime.parse(data['date']),
      type: FamilyExpenseType.values[data['type'] ?? 0],
      memberId: data['memberId'],
      splitAllocations: rawSplit?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'description': description,
      'envelopeId': envelopeId,
      'date': date.toIso8601String(),
      'type': type.index,
      'memberId': memberId,
      'splitAllocations': splitAllocations,
    };
  }

  /// Quanto di questa spesa "pesa" su un membro specifico
  double quotaFor(String memberId, int totalMembersCount) {
    switch (type) {
      case FamilyExpenseType.personal:
        return this.memberId == memberId ? amount : 0;
      case FamilyExpenseType.shared:
        return totalMembersCount == 0 ? 0 : amount / totalMembersCount;
      case FamilyExpenseType.split:
        return splitAllocations?[memberId] ?? 0;
    }
  }
}
