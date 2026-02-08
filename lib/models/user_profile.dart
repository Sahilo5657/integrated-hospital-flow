class UserProfile {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });
}

enum UserRole { patient, doctor, staff }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.patient:
        return "Patient";
      case UserRole.doctor:
        return "Doctor";
      case UserRole.staff:
        return "Receptionist/Admin";
    }
  }
}
