/// Una voce dello changelog "Novità e aggiornamenti" (Fase G del piano
/// post-beta). Il contenuto è scritto a mano su Firestore (Console/Admin
/// SDK), mai dal client — vedi `firestore.rules` (`allow write: if false`).
class ChangelogEntry {
  final String id;
  final String version;
  final DateTime date;
  final String title;
  final List<String> items;

  ChangelogEntry({
    required this.id,
    required this.version,
    required this.date,
    required this.title,
    required this.items,
  });

  factory ChangelogEntry.fromMap(String id, Map<String, dynamic> data) {
    return ChangelogEntry(
      id: id,
      version: data['version'] ?? '',
      date: DateTime.parse(data['date']),
      title: data['title'] ?? '',
      items: List<String>.from(data['items'] ?? []),
    );
  }
}
