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

  Challenge({
    required this.id,
    required this.title,
    required this.type,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
    this.envelopeId,
  });

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
    };
  }
}
