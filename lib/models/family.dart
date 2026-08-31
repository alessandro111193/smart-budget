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

  Family({required this.id, required this.name, required this.ownerId});

  factory Family.fromMap(String id, Map<String, dynamic> data) {
    return Family(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
    );
  }
}
