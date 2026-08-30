enum ChallengeType { weeks52, fixedAmount, custom }

class Challenge {
  final String id;
  final String title;
  final ChallengeType type;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;

  Challenge({
    required this.id,
    required this.title,
    required this.type,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
  });

  double get percentComplete =>
      targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  /// Per l'obiettivo personalizzato: quota mensile necessaria
  double? get monthlyQuota {
    if (deadline == null) return null;
    final now = DateTime.now();
    final monthsLeft =
        (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    if (monthsLeft <= 0) return null;
    return (targetAmount - savedAmount) / monthsLeft;
  }
}
