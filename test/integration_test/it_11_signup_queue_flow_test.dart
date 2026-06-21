// IT-11: Patient sign-up → NFC card linking → queue join — end-to-end flow
//
// Integration scope: AuthService.signUp (patient registration + card linking)
// → AuthService.joinQueue (queue entry creation with ETA)
// → DoctorSettingsService.checkQueueAccess (daily limit enforcement)
//
// Uses FakeFirebaseFirestore + MockFirebaseAuth to run against real service
// logic without touching actual Firebase infrastructure.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/auth/auth_service.dart';
import 'package:hospital_flow_app/services/doctor_settings_service.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  group('IT-11: Patient sign-up + NFC card linking + queue join', () {
    late FakeFirebaseFirestore fs;

    setUp(() {
      fs = FakeFirebaseFirestore();
    });

    // ── Sign-up: role enforcement ────────────────────────────────────────────

    test('Only patient role can self-register — doctor role is rejected', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final svc = AuthService(auth: auth, firestore: fs);

      expect(
        () async => svc.signUp('doctor@hospital.com', 'pass', 'Dr X', 'doctor'),
        throwsException,
        reason: 'Only patients can self-register via the app',
      );
    });

    test('Only patient role can self-register — staff role is rejected', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final svc = AuthService(auth: auth, firestore: fs);

      expect(
        () async => svc.signUp('staff@hospital.com', 'pass', 'Staff Y', 'staff'),
        throwsException,
      );
    });

    // ── Sign-up: NFC card validation ─────────────────────────────────────────

    test('Sign-up rejects patient when NFC card is not activated', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final svc = AuthService(auth: auth, firestore: fs);
      // No activated_cards document → not activated

      expect(
        () async => svc.signUp(
          'patient@test.com', 'pass', 'Patient', 'patient',
          nfcCardId: 'CARD-NOT-ACTIVATED',
        ),
        throwsException,
        reason: 'Unactivated card must be rejected during sign-up',
      );
    });

    test('Sign-up rejects patient when NFC card is already linked to another account', () async {
      await fs.collection('activated_cards').doc('CARD-TAKEN').set({
        'isLinkedToApp': true,
        'linkedUid': 'existing-uid',
      });

      final auth = MockFirebaseAuth(signedIn: false);
      final svc = AuthService(auth: auth, firestore: fs);

      expect(
        () async => svc.signUp(
          'patient2@test.com', 'pass', 'Patient2', 'patient',
          nfcCardId: 'CARD-TAKEN',
        ),
        throwsException,
        reason: 'Already-linked NFC card must be rejected',
      );
    });

    // ── Queue join: duplicate prevention ─────────────────────────────────────

    test('joinQueue prevents the same patient from joining twice', () async {
      await fs.collection('queues').doc('q-exist').set({
        'doctorId': 'dr-uid',
        'patientName': 'Existing Patient',
        'patientId': 'existing-uid',
        'tokenNo': 1,
        'status': 'waiting',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final auth = MockFirebaseAuth(signedIn: true, mockUser: patientUser);
      final svc = AuthService(auth: auth, firestore: fs);

      expect(
        () async => svc.joinQueue('Existing Patient', 'existing-uid', 'dr-uid'),
        throwsException,
        reason: 'Patient already waiting must not create a duplicate entry',
      );
    });

    // ── Queue join: token assignment ──────────────────────────────────────────

    test('joinQueue assigns token 1 when the queue is empty', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: patientUser);
      final svc = AuthService(auth: auth, firestore: fs);

      await svc.joinQueue('New Patient', 'new-uid', 'dr-uid');

      final snapshot = await fs.collection('queues').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first['tokenNo'], 1);
      expect(snapshot.docs.first['patientName'], 'New Patient');
      expect(snapshot.docs.first['status'], 'waiting');
    });

    // ── DoctorSettings + queue: daily limit integration ────────────────────────

    test('checkQueueAccess + joinQueue: limit blocks after threshold is reached', () async {
      // Configure doctor with a daily limit of 1
      await fs.collection('doctor_settings').doc('dr-limit').set({
        'dailyLimit': 1,
        'endTimeHour': 23,
        'endTimeMinute': 59,
      });

      // One queue entry already today
      final today = DateTime.now();
      await fs.collection('queues').doc('q-today').set({
        'doctorId': 'dr-limit',
        'status': 'done',
        'timestamp': Timestamp.fromDate(
          DateTime(today.year, today.month, today.day, 9, 0),
        ),
      });

      // checkQueueAccess should block
      final settingsSvc = DoctorSettingsService(doctorId: 'dr-limit', firestore: fs);
      final blockMsg = await settingsSvc.checkQueueAccess();

      expect(blockMsg, isNotNull,
          reason: 'Daily limit of 1 reached → access must be blocked');
      expect(blockMsg, contains('patient limit'),
          reason: 'Block message must mention patient limit');
    });
  });
}
