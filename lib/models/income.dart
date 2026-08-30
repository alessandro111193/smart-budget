class Income {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category; // Aggiunto
  final Map<String, double> allocations;

  Income({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.allocations,
  });

  factory Income.fromMap(String id, Map<String, dynamic> data) {
    final rawAllocations = data['allocations'] as Map<dynamic, dynamic>? ?? {};
    final allocations = rawAllocations.map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    );

    return Income(
      id: id,
      description: data['description'] ?? 'Entrata',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: data['date'] != null
          ? DateTime.parse(data['date'])
          : DateTime.now(),
      category:
          data['category'] ?? 'Stipendio', // Legge la categoria da Firestore
      allocations: allocations,
    );
  }
}
