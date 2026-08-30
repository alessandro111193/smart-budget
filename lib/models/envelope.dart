class Envelope {
  final String id;
  final String name;
  final String category;
  final double budget;
  final double balance;
  final String icon;

  Envelope({
    required this.id,
    required this.name,
    required this.category,
    required this.budget,
    required this.balance,
    required this.icon,
  });

  double get percentUsed => budget == 0 ? 0 : (budget - balance) / budget;
}
