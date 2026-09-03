import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType { saving, spendingLimit }

class Challenge {
  final String id;
  final String title;
  final ChallengeType type;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final String? envelopeId;

  /// Quando la challenge è stata creata. Nullable perché le challenge
  /// create prima dell'introduzione di questo campo non lo hanno: in quel
  /// caso [isOnTrack] restituisce semplicemente null invece di un dato
  /// inventato.
  final DateTime? createdAt;

  Challenge({
    required this.id,
    required this.title,
    required this.type,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
    this.envelopeId,
    this.createdAt,
  });

  /// Copia della challenge con un [savedAmount] diverso. Usata per i
  /// Sinking Funds collegati a una busta: il saldo reale della busta
  /// (Envelope.balance) diventa l'unica fonte di verità per il progresso —
  /// niente più un contatore separato che può disallinearsi dal saldo
  /// effettivo, come segnalato nel controllo di stato pre-beta.
  Challenge copyWithSavedAmount(double savedAmount) {
    return Challenge(
      id: id,
      title: title,
      type: type,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
      envelopeId: envelopeId,
      createdAt: createdAt,
    );
  }

  /// Per "saving": quanto manca in percentuale verso l'obiettivo.
  /// Per "spendingLimit": quanto è già stato consumato del tetto di spesa.
  double get percentComplete =>
      targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0, 2);

  /// Solo per le sfide di risparmio con scadenza: quota mensile necessaria.
  double? get monthlyQuota {
    if (type != ChallengeType.saving || deadline == null) return null;
    final now = DateTime.now();
    final monthsLeft =
        (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    if (monthsLeft <= 0) return null;
    final remainingAmount = targetAmount - savedAmount;
    if (remainingAmount <= 0) return 0;
    return remainingAmount / monthsLeft;
  }

  /// Solo per "spendingLimit": true se il tetto è stato superato.
  bool get limitExceeded =>
      type == ChallengeType.spendingLimit && savedAmount > targetAmount;

  /// Punto 7 del piano AI Premium: controllo automatico "il piano sta
  /// andando bene?" per le sfide di risparmio con scadenza — confronta il
  /// progresso atteso (tempo trascorso dalla creazione / tempo totale a
  /// disposizione) con quello reale (risparmiato / obiettivo). Solo
  /// calcolo Dart, zero costo. Restituisce null quando manca [createdAt]
  /// (challenge create prima dell'introduzione di questo campo) o
  /// [deadline], invece di un giudizio inventato.
  bool? get isOnTrack {
    if (type != ChallengeType.saving ||
        deadline == null ||
        createdAt == null) {
      return null;
    }
    final totalDays = deadline!.difference(createdAt!).inDays;
    if (totalDays <= 0) return null;
    final elapsedDays = DateTime.now()
        .difference(createdAt!)
        .inDays
        .clamp(0, totalDays);
    final expectedProgress = elapsedDays / totalDays;
    final actualProgress = targetAmount == 0
        ? 0.0
        : (savedAmount / targetAmount).clamp(0.0, 1.0);
    // Margine di tolleranza: non allarmare per scarti minimi.
    return actualProgress >= expectedProgress - 0.05;
  }

  /// Sotto questa soglia di giorni trascorsi dalla creazione non proiettiamo
  /// il ritmo di risparmio: con pochi giorni di dati la proiezione sarebbe
  /// troppo rumorosa (es. un primo versamento grande subito dopo la
  /// creazione farebbe sembrare l'obiettivo quasi raggiunto).
  static const int _minDaysForProjection = 3;

  /// Data stimata di raggiungimento dell'obiettivo al ritmo di risparmio
  /// attuale (diverso da [monthlyQuota], che dice quanto servirebbe
  /// mettere da parte per rispettare la scadenza — questo dice invece
  /// "continuando così, ce la farai il [data]", prima o dopo la scadenza
  /// che sia). Solo calcolo Dart, zero costo. Null se: non è un obiettivo
  /// di risparmio, manca [createdAt], sono passati troppo pochi giorni per
  /// una stima affidabile, o non è stato ancora risparmiato nulla (nessun
  /// ritmo da proiettare — mai una data inventata).
  DateTime? get projectedCompletionDate {
    if (type != ChallengeType.saving || createdAt == null) return null;
    final elapsedDays = DateTime.now().difference(createdAt!).inDays;
    if (elapsedDays < _minDaysForProjection) return null;
    final remainingAmount = targetAmount - savedAmount;
    if (remainingAmount <= 0) return DateTime.now();
    if (savedAmount <= 0) return null;
    final dailyRate = savedAmount / elapsedDays;
    if (dailyRate <= 0) return null;
    final daysNeeded = (remainingAmount / dailyRate).ceil();
    return DateTime.now().add(Duration(days: daysNeeded));
  }

  /// Conversione da DocumentSnapshot di Firestore a oggetto Challenge
  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Challenge(
      id: doc.id,
      title: data['title'] as String? ?? '',
      type: ChallengeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ChallengeType.saving,
      ),
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (data['savedAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      envelopeId: data['envelopeId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Conversione da oggetto Challenge a Map per la scrittura su Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'envelopeId': envelopeId,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}
