class UserProfile {
  final String uid;
  final String email;
  final String role; // 'patient', 'doctor', 'staff'
  final String name;

  UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    required this.name
  });

  // Factory to create a UserProfile from Firestore data
  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'patient', // Default to patient if not specified
      name: data['name'] ?? '',
    );
  }

  // Method to convert UserProfile to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
    };
  }
}