/// Valore sentinella usato nei picker busta (form spesa, Scanner) per la
/// scelta "Spese generali" prima che la busta reale sia stata creata/letta
/// da Firestore — mai salvato come envelopeId reale di una spesa (viene
/// sempre risolto in un id reale tramite [FirestoreService.ensureGeneralEnvelope]
/// prima del salvataggio).
const String kGeneralEnvelopeSentinel = '__general__';

/// Valore sentinella usato nei picker busta per l'opzione "+ Nuova busta"
/// (creazione al volo durante la registrazione di una spesa).
const String kNewEnvelopeSentinel = '__new__';

class Envelope {
  final String id;
  final String name;
  final String category;
  final double budget;
  final double balance;
  final String icon;

  /// True solo per la busta "Spese generali" auto-creata (al più una per
  /// utente) quando si registra una spesa senza scegliere una busta propria
  /// — nessun budget reale, esclusa dagli avvisi di budget.
  final bool isGeneral;

  Envelope({
    required this.id,
    required this.name,
    required this.category,
    required this.budget,
    required this.balance,
    required this.icon,
    this.isGeneral = false,
  });

  double get percentUsed => budget == 0 ? 0 : (budget - balance) / budget;
}
