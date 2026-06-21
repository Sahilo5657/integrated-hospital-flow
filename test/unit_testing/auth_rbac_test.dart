// UT-01: Auth/RBAC — resolveRole()
//
// Covers: UserProfile.fromFirestore(), role field resolution, doctor permission gate.
// The role_router.dart uses profile.role to route and gate actions — this test
// verifies that an authenticated Doctor profile resolves correctly and that
// only the doctor role passes the permission check.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/user_profile.dart';

// Mirrors the role resolution used in role_router.dart:
// RoleRouter reads profile.role and gates actions accordingly.
String resolveRole(UserProfile profile) => profile.role;

bool isDoctorActionPermitted(String role) => role.toLowerCase() == 'doctor';

void main() {
  group('UT-01: Auth/RBAC — resolveRole()', () {
    test(
        'Authenticated user with role=doctor returns "doctor" '
        'and doctor actions are permitted', () {
      // Arrange
      final profile = UserProfile.fromFirestore(
        {'email': 'doctor@hospital.com', 'role': 'doctor', 'name': 'Dr. Smith'},
        'uid-doctor-001',
      );

      // Act
      final resolvedRole = resolveRole(profile);

      // Assert
      expect(resolvedRole, equals('doctor'),
          reason: 'resolveRole must return the profile role as-is');
      expect(isDoctorActionPermitted(resolvedRole), isTrue,
          reason: 'Doctor role must unlock doctor-only actions');
    });

    test('Patient role does not receive doctor permissions', () {
      final profile = UserProfile.fromFirestore(
        {'email': 'patient@hospital.com', 'role': 'patient', 'name': 'Jane Doe'},
        'uid-patient-001',
      );

      final resolvedRole = resolveRole(profile);

      expect(resolvedRole, equals('patient'));
      expect(isDoctorActionPermitted(resolvedRole), isFalse,
          reason: 'Patient role must not pass doctor permission gate');
    });

    test('Missing role field in Firestore data defaults to "patient"', () {
      // Simulate a Firestore document with no role field
      final profile = UserProfile.fromFirestore(
        {'email': 'unknown@hospital.com', 'name': 'Unknown User'},
        'uid-no-role',
      );

      final resolvedRole = resolveRole(profile);

      expect(resolvedRole, equals('patient'),
          reason: 'UserProfile.fromFirestore defaults to patient when role is absent');
      expect(isDoctorActionPermitted(resolvedRole), isFalse);
    });

    test('Staff role is resolved correctly and is not treated as doctor', () {
      final profile = UserProfile.fromFirestore(
        {'email': 'staff@hospital.com', 'role': 'staff', 'name': 'Nurse Ali'},
        'uid-staff-001',
      );

      final resolvedRole = resolveRole(profile);

      expect(resolvedRole, equals('staff'));
      expect(isDoctorActionPermitted(resolvedRole), isFalse);
    });
  });
}
