// firebase_test_setup.dart
//
// Provides shared helpers used by widget and service tests:
//   • setupFirebaseForTests() — initialises Firebase mocks so that
//     FirebaseAuth.instance and FirebaseFirestore.instance don't crash in
//     widget tests running without a real Firebase project.
//   • buildTestApp()         — wraps a widget in MaterialApp + AuthService provider.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/auth/auth_service.dart';
import 'package:provider/provider.dart';

export 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
export 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Initialises Firebase mocks so screens can safely call
/// FirebaseAuth.instance and FirebaseFirestore.instance without crashing.
///
/// Call this inside setUpAll() for every test file that pumps a widget
/// which touches Firebase.
Future<void> setupFirebaseForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // setupFirebaseCoreMocks() registers a mock for the Firebase Core
  // pigeon channel so that Firebase.initializeApp() works in tests.
  setupFirebaseCoreMocks();
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (e) {
    // Ignore duplicate-app errors when multiple test files share the process.
    if (e.code != 'duplicate-app') rethrow;
  } catch (_) {
    // Ignore any other initialization errors in test context.
  }
}

/// Returns a [FakeFirebaseFirestore] pre-seeded with a test doctor user profile,
/// a test patient user profile, and one queue entry.
FakeFirebaseFirestore seededFirestore() {
  final fs = FakeFirebaseFirestore();

  // Doctor user
  fs.collection('users').doc('doctor-uid').set({
    'name': 'Dr Test',
    'email': 'sahilo5657@gmail.com',
    'role': 'doctor',
  });

  // Patient user
  fs.collection('users').doc('patient-uid').set({
    'name': 'Test Patient',
    'email': 'testpatient@test.com',
    'role': 'patient',
  });

  // One queue entry
  fs.collection('queues').doc('q-1').set({
    'doctorId': 'sahilo5657@gmail.com',
    'patientName': 'Test Patient',
    'patientId': 'patient-uid',
    'tokenNo': 1,
    'status': 'waiting',
    'queueStatus': 'Waiting',
    'etaMins': 15,
    'timestamp': DateTime(2026, 6, 19, 9, 0),
  });

  // One encounter
  fs.collection('encounters').doc('enc-1').set({
    'patientId': 'patient-uid',
    'patientName': 'Test Patient',
    'doctorId': 'sahilo5657@gmail.com',
    'rawNotes': 'Patient has hypertension.',
    'timestamp': DateTime(2026, 6, 19, 9, 0),
  });

  // One summary (cache)
  fs.collection('summaries').doc('sum-1').set({
    'encounterId': 'enc-1',
    'summaryText': 'Hypertension diagnosis confirmed.',
    'timestamp': DateTime(2026, 6, 19, 9, 0),
  });

  // One activated card
  fs.collection('activated_cards').doc('CARD-001').set({
    'cardId': 'CARD-001',
    'patientName': 'Test Patient',
    'phoneNumber': '+601234567890',
    'status': 'active',
    'isLinkedToApp': false,
  });

  return fs;
}

/// Wraps [child] in a MaterialApp + ChangeNotifierProvider<AuthService>.
/// Uses [mockUser] to determine the signed-in state.
Widget buildTestApp(
  Widget child, {
  MockUser? mockUser,
  FakeFirebaseFirestore? fakeFirestore,
}) {
  final isSignedIn = mockUser != null;
  final auth = MockFirebaseAuth(signedIn: isSignedIn, mockUser: mockUser);
  final firestore = fakeFirestore ?? seededFirestore();
  final authService = AuthService(auth: auth, firestore: firestore);

  return ChangeNotifierProvider<AuthService>.value(
    value: authService,
    child: MaterialApp(home: child),
  );
}

/// Convenience: a MockUser representing a logged-in doctor.
MockUser get doctorUser => MockUser(
      uid: 'doctor-uid',
      email: 'sahilo5657@gmail.com',
      displayName: 'Dr Test',
    );

/// Convenience: a MockUser representing a logged-in patient.
MockUser get patientUser => MockUser(
      uid: 'patient-uid',
      email: 'testpatient@test.com',
      displayName: 'Test Patient',
    );

/// Convenience: a MockUser representing a logged-in staff member.
MockUser get staffUser => MockUser(
      uid: 'staff-uid',
      email: 'eshaan5657@gmail.com',
      displayName: 'Staff Member',
    );
