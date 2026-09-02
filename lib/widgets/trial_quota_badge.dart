import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Indicatore "quante te ne restano" per un utente in Trial (Premium non ha
/// limiti, Free non arriva mai a queste schermate) — mostrato a contesto
/// dove l'azione viene compiuta (Scanner, Chat AI), non solo nella
/// schermata Premium dove i contatori esistevano già ma erano invisibili
/// nel momento in cui servono davvero.
class TrialQuotaBadge extends StatelessWidget {
  final int Function(AppUser) used;
  final int max;
  final String label;

  const TrialQuotaBadge({
    super.key,
    required this.used,
    required this.max,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: FirestoreService().streamUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null || user.isPremium || !user.isTrialActive) {
          return const SizedBox.shrink();
        }
        final remaining = (max - used(user)).clamp(0, max);
        final low = remaining <= max ~/ 5;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: low
                ? AppColors.warning.withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$label: $remaining/$max rimasti questo mese',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: low ? AppColors.warning : AppColors.neutral,
            ),
          ),
        );
      },
    );
  }
}
