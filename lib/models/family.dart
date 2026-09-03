import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String userId;
  final String name;
  final String role; // "owner" o "member"
  final String colorTag;

  FamilyMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.colorTag,
  });

  factory FamilyMember.fromMap(String id, Map<String, dynamic> data) {
    return FamilyMember(
      userId: id,
      name: data['name'] ?? '',
      role: data['role'] ?? 'member',
      colorTag: data['colorTag'] ?? '#16B98C',
    );
  }
}

class FamilyInvite {
  final String id;
  final String email;
  final String status;

  FamilyInvite({required this.id, required this.email, required this.status});

  factory FamilyInvite.fromMap(String id, Map<String, dynamic> data) {
    return FamilyInvite(
      id: id,
      email: data['email'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}

class Family {
  final String id;
  final String name;
  final String ownerId;

  /// Blocco D: stato Premium/Trial dell'owner denormalizzato qui, perché
  /// un membro non-owner non può leggere users/{uid} dell'owner (le
  /// Firestore Rules lo permettono solo a se stessi). Aggiornati dalle
  /// Cloud Function che toccano lo stato Premium dell'owner
  /// (createFamily, adminSetPremiumStatus, startTrial, verifyPlayPurchase).
  final bool ownerIsPremium;
  final DateTime? ownerTrialEnd;

  Family({
    required this.id,
    required this.name,
    required this.ownerId,
    this.ownerIsPremium = false,
    this.ownerTrialEnd,
  });

  factory Family.fromMap(String id, Map<String, dynamic> data) {
    final trialEndRaw = data['ownerTrialEnd'];
    return Family(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerIsPremium: data['ownerIsPremium'] == true,
      ownerTrialEnd: trialEndRaw is Timestamp ? trialEndRaw.toDate() : null,
    );
  }

  /// true se l'owner ha Premium o Trial attivo — stessa equivalenza di
  /// AppUser.hasAiAccess, qui applicata all'accesso familiare invece che
  /// a quello personale.
  bool get accessActive =>
      ownerIsPremium || (ownerTrialEnd != null && ownerTrialEnd!.isAfter(DateTime.now()));
}
