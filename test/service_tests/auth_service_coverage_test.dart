// auth_service_coverage_test.dart — covers AuthService with FakeFirebaseFirestore + MockFirebaseAuth
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/auth/auth_service.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  late FakeFirebaseFirestore fakeFs;
  late MockFirebaseAuth mockAuth;
  late AuthService service;

  setUp(() async {
    await setupFirebaseForTests();
    fakeFs = seededFirestore();
    mockAuth = MockFirebaseAuth(signedIn: true, mockUser: doctorUser);
    service = AuthService(auth: mockAuth, firestore: fakeFs);
  });

  // ── getUserProfile ────────────────────────────────────────────────────────

  group('getUserProfile', () {
    test('returns UserProfile when document exists', () async {
      final profile = await service.getUserProfile('doctor-uid');
      expect(profile, isNotNull);
      expect(profile!.name, 'Dr Test');
      expect(profile.role, 'doctor');
    });

    test('returns null when document does not exist', () async {
      final profile = await service.getUserProfile('nonexistent-uid');
      expect(profile, isNull);
    });
  });

  // ── userProfileStream ─────────────────────────────────────────────────────

  group('userProfileStream', () {
    test('emits UserProfile when doc exists', () async {
      final stream = service.userProfileStream('doctor-uid');
      final profile = await stream.first;
      expect(profile, isNotNull);
      expect(profile!.email, 'sahilo5657@gmail.com');
    });

    test('emits null when doc does not exist', () async {
      final stream = service.userProfileStream('missing-uid');
      final profile = await stream.first;
      expect(profile, isNull);
    });
  });

  // ── joinQueue ─────────────────────────────────────────────────────────────

  group('joinQueue', () {
    test('adds a new queue entry when patient is not already waiting', () async {
      // Patient 'new-uid' not in queue yet
      await service.joinQueue('New Patient', 'new-uid', 'test-doctor-uid');

      final snapshot = await fakeFs.collection('queues').get();
      final names = snapshot.docs.map((d) => d['patientName']).toList();
      expect(names, contains('New Patient'));
    });

    test('throws when patient is already in the queue', () async {
      // 'Test Patient' is already in the seeded queue with status 'waiting'
      expect(
        () async => service.joinQueue('Test Patient', 'patient-uid', 'test-doctor-uid'),
        throwsException,
      );
    });
  });

  // ── callNext ──────────────────────────────────────────────────────────────

  group('callNext', () {
    test('moves oldest waiting patient to serving', () async {
      await service.callNext();

      final snapshot = await fakeFs.collection('queues').get();
      final serving = snapshot.docs.where((d) => d['status'] == 'serving');
      expect(serving.length, 1);
      expect(serving.first['patientName'], 'Test Patient');
    });

    test('handles empty waiting queue gracefully', () async {
      // Mark the only waiting patient as done first
      await fakeFs.collection('queues').doc('q-1').update({'status': 'done'});
      // callNext should not throw even with no waiting patients
      await expectLater(service.callNext(), completes);
    });
  });

  // ── completeVisit ─────────────────────────────────────────────────────────

  group('completeVisit', () {
    test('throws when no patient is being served', () async {
      // No patient has status 'serving' in the seeded data
      expect(() async => service.completeVisit(), throwsException);
    });

    test('marks serving patient as done and calls next', () async {
      // Put the patient into 'serving' state first
      await fakeFs.collection('queues').doc('q-1').update({'status': 'serving'});
      await service.completeVisit();

      final doc = await fakeFs.collection('queues').doc('q-1').get();
      expect(doc['status'], 'done');
    });
  });

  // ── signUp ────────────────────────────────────────────────────────────────

  group('signUp — validation paths', () {
    test('throws if patient NFC card ID is null', () async {
      expect(
        () async => service.signUp('a@b.com', 'pass', 'Name', 'patient'),
        throwsException,
      );
    });

    test('throws if patient NFC card ID is empty string', () async {
      expect(
        () async => service.signUp('a@b.com', 'pass', 'Name', 'patient', nfcCardId: ''),
        throwsException,
      );
    });

    test('throws if NFC card is not activated', () async {
      // CARD-UNKNOWN is not in activated_cards
      expect(
        () async => service.signUp('a@b.com', 'pass', 'Name', 'patient', nfcCardId: 'CARD-UNKNOWN'),
        throwsException,
      );
    });
  });

  // ── signUp — additional edge cases ───────────────────────────────────────

  group('signUp — additional paths', () {
    test('throws when NFC card is already linked to another account', () async {
      await fakeFs.collection('activated_cards').doc('CARD-ALREADY-LINKED').set({
        'isLinkedToApp': true,
        'linkedUid': 'some-other-uid',
      });

      expect(
        () async => service.signUp(
          'another@b.com', 'pass', 'Another', 'patient',
          nfcCardId: 'CARD-ALREADY-LINKED',
        ),
        throwsException,
      );
    });

    test('throws when attempting to register with a non-patient role (doctor)', () async {
      expect(
        () async => service.signUp(
          'doc@hospital.com', 'pass', 'Dr Name', 'doctor',
        ),
        throwsException,
      );
    });

    test('throws when attempting to register with a non-patient role (staff)', () async {
      expect(
        () async => service.signUp(
          'staff@hospital.com', 'pass', 'Staff Name', 'staff',
        ),
        throwsException,
      );
    });
  });

  // ── joinQueue — additional paths ──────────────────────────────────────────

  group('joinQueue — blocked by settings', () {
    test('throws when DoctorSettingsService daily limit is 0 (blocks all new patients)', () async {
      // A daily limit of 0 means no new patients can join regardless of queue state
      await fakeFs.collection('doctor_settings').doc('dr-blocked').set({
        'dailyLimit': 0,
        'endTimeHour': 23,
        'endTimeMinute': 59,
      });

      expect(
        () async => service.joinQueue('New Patient', 'brand-new-uid', 'dr-blocked'),
        throwsException,
      );
    });
  });

  // ── callNext — additional coverage ───────────────────────────────────────

  group('callNext — with existing serving patient', () {
    test('marks serving patient as done and promotes next waiting when both exist', () async {
      // Use a fresh isolated Firestore to avoid tokenNo conflicts with seeded data
      final freshFs = FakeFirebaseFirestore();
      final freshService = AuthService(auth: mockAuth, firestore: freshFs);

      await freshFs.collection('queues').doc('q-svc').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Currently Serving',
        'patientId': 'cs-uid',
        'tokenNo': 1,
        'status': 'serving',
        'timestamp': DateTime.now(),
      });
      await freshFs.collection('queues').doc('q-wait').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Next Waiting',
        'patientId': 'nw-uid',
        'tokenNo': 2,
        'status': 'waiting',
        'timestamp': DateTime.now(),
      });

      await freshService.callNext();

      final servingDoc = await freshFs.collection('queues').doc('q-svc').get();
      final waitingDoc = await freshFs.collection('queues').doc('q-wait').get();

      expect(servingDoc['status'], 'done');
      expect(waitingDoc['status'], 'serving');
    });
  });

  // ── signIn / signOut ──────────────────────────────────────────────────────

  group('signIn', () {
    test('calls Firebase signIn without crashing', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final svc = AuthService(auth: auth, firestore: fakeFs);
      // MockFirebaseAuth always succeeds for test@test.com
      await expectLater(
        svc.signIn('test@test.com', 'password'),
        completes,
      );
    });
  });

  group('signOut', () {
    test('signs out without crashing', () async {
      await expectLater(service.signOut(), completes);
    });
  });
}
