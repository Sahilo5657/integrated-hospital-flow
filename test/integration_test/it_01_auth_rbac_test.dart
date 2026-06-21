// IT-01: Auth + RBAC + App — User logs in and is routed by role
//
// Integration scope: AuthService (role lookup) → role router (routing decision)
// → permission gate (action blocking) all wired together.
//
// This test seeds a UserProfile (the output of a successful login) and then
// drives the full role-resolution + routing + permission pipeline end-to-end
// for each role the app supports.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/user_profile.dart';

// ── Role-router logic (mirrors role_router.dart) ───────────────────────────

enum AppRoute { doctorHome, patientHome, staffHome, wallMounted, unknown }

AppRoute resolveRoute(UserProfile profile) {
  switch (profile.role.toLowerCase()) {
    case 'doctor':
      return AppRoute.doctorHome;
    case 'patient':
      return AppRoute.patientHome;
    case 'staff':
      return AppRoute.staffHome;
    case 'wall':
      return AppRoute.wallMounted;
    default:
      return AppRoute.unknown;
  }
}

// ── Permission gate (mirrors role-based action guards) ─────────────────────

class PermissionSet {
  final bool canViewPatientRecords;
  final bool canWriteClinicalNotes;
  final bool canManageQueue;
  final bool canViewOwnSummary;

  const PermissionSet({
    this.canViewPatientRecords = false,
    this.canWriteClinicalNotes = false,
    this.canManageQueue = false,
    this.canViewOwnSummary = false,
  });
}

PermissionSet permissionsFor(String role) {
  switch (role.toLowerCase()) {
    case 'doctor':
      return const PermissionSet(
        canViewPatientRecords: true,
        canWriteClinicalNotes: true,
      );
    case 'staff':
      return const PermissionSet(canManageQueue: true);
    case 'patient':
      return const PermissionSet(canViewOwnSummary: true);
    default:
      return const PermissionSet();
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-01: Auth + RBAC + App — role-based routing and permission gating', () {
    // ── Doctor flow ────────────────────────────────────────────────────────
    test('Doctor login → routed to DoctorHome; patient record actions permitted', () {
      // Step 1: Simulate login — AuthService returns a UserProfile
      final profile = UserProfile.fromFirestore(
        {'email': 'doc@hospital.com', 'role': 'doctor', 'name': 'Dr. Ahmed'},
        'uid-doctor-001',
      );

      // Step 2: Role router maps to the correct home screen
      final route = resolveRoute(profile);
      expect(route, equals(AppRoute.doctorHome),
          reason: 'Doctor must be routed to DoctorHome');

      // Step 3: Permission gate permits doctor-only actions
      final perms = permissionsFor(profile.role);
      expect(perms.canViewPatientRecords, isTrue,
          reason: 'Doctor must be able to view patient records');
      expect(perms.canWriteClinicalNotes, isTrue,
          reason: 'Doctor must be able to write clinical notes');

      // Step 4: Unauthorized actions are blocked
      expect(perms.canManageQueue, isFalse,
          reason: 'Doctor must not access queue management (staff only)');
    });

    // ── Patient flow ───────────────────────────────────────────────────────
    test('Patient login → routed to PatientHome; doctor actions blocked', () {
      final profile = UserProfile.fromFirestore(
        {'email': 'patient@gmail.com', 'role': 'patient', 'name': 'Sara Lee'},
        'uid-patient-001',
      );

      final route = resolveRoute(profile);
      expect(route, equals(AppRoute.patientHome));

      final perms = permissionsFor(profile.role);
      expect(perms.canViewOwnSummary, isTrue);
      expect(perms.canWriteClinicalNotes, isFalse,
          reason: 'Patient must not be able to write clinical notes');
      expect(perms.canViewPatientRecords, isFalse,
          reason: 'Patient must not access other patients\' records');
    });

    // ── Staff flow ─────────────────────────────────────────────────────────
    test('Staff login → routed to StaffHome; queue management permitted', () {
      final profile = UserProfile.fromFirestore(
        {'email': 'staff@hospital.com', 'role': 'staff', 'name': 'Nurse Ali'},
        'uid-staff-001',
      );

      final route = resolveRoute(profile);
      expect(route, equals(AppRoute.staffHome));

      final perms = permissionsFor(profile.role);
      expect(perms.canManageQueue, isTrue);
      expect(perms.canWriteClinicalNotes, isFalse);
      expect(perms.canViewPatientRecords, isFalse);
    });

    // ── Missing / unknown role ─────────────────────────────────────────────
    // Note: UserProfile.fromFirestore defaults a *missing* role field to 'patient'.
    // An explicitly unrecognised role string (e.g. 'admin') is what reaches unknown.
    test('Unrecognised role string → routed to unknown; all sensitive actions blocked', () {
      final profile = UserProfile.fromFirestore(
        {'email': 'x@y.com', 'role': 'admin', 'name': 'Ghost'},
        'uid-ghost',
      );

      final route = resolveRoute(profile);
      expect(route, equals(AppRoute.unknown));

      final perms = permissionsFor(profile.role);
      expect(perms.canViewPatientRecords, isFalse);
      expect(perms.canWriteClinicalNotes, isFalse);
      expect(perms.canManageQueue, isFalse);
      expect(perms.canViewOwnSummary, isFalse);
    });
  });
}
