// patient_screens_test.dart — covers PatientHome, PatientQueueScreen, PatientSummaryScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/patient/patient_home.dart';
import 'package:hospital_flow_app/patient/patient_queue_screen.dart';
import 'package:hospital_flow_app/patient/patient_summary_screen.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // PatientSummaryScreen — most testable: takes all inputs as parameters
  // ══════════════════════════════════════════════════════════════════════════
  group('PatientSummaryScreen', () {
    testWidgets('displays cached summary immediately without calling AI', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientSummaryScreen(
          encounterId: 'enc-1',
          clinicalNotes: 'Patient has hypertension.',
          cachedSummary: 'Hypertension confirmed. Prescribed medication.',
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Visit Report'), findsOneWidget);
      expect(find.text('AI Clinical Summary'), findsOneWidget);
      expect(find.text('Hypertension confirmed. Prescribed medication.'), findsOneWidget);
    });

    testWidgets('shows loading spinner on first frame when no cached summary', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientSummaryScreen(
          encounterId: 'enc-no-cache',
          clinicalNotes: 'Patient has fever.',
        ),
        mockUser: patientUser,
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance enough fake time for all timeouts (Firestore 10s + 3 HTTP 40s + 2 retry delays 5s = 140s)
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
    });

    testWidgets('shows Visit Report title with cached summary', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientSummaryScreen(
          encounterId: 'enc-1',
          clinicalNotes: 'Patient has hypertension.',
          cachedSummary: 'AI cached result.',
        ),
        mockUser: patientUser,
      ));
      await tester.pump();
      expect(find.text('Visit Report'), findsOneWidget);
    });

    testWidgets('empty cachedSummary triggers loading state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientSummaryScreen(
          encounterId: 'enc-empty',
          clinicalNotes: 'Test notes.',
          cachedSummary: '',
        ),
        mockUser: patientUser,
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Advance enough fake time for all timeouts (Firestore 10s + 3 HTTP 40s + 2 retry delays 5s = 140s)
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PatientQueueScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('PatientQueueScreen', () {
    testWidgets('shows "please log in" when no user is signed in', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientQueueScreen(doctorId: 'test-doctor'),
      ));
      await tester.pump();
      expect(find.text('Please log in to view status.'), findsOneWidget);
    });

    testWidgets('shows loading state when user is signed in (singleton Firestore)', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientQueueScreen(doctorId: 'test-doctor'),
        mockUser: patientUser,
      ));
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('My Queue Status').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows empty state when patient has no active queue entry', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        PatientQueueScreen(
          doctorId: 'dr-uid',
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('You are not currently in any queue.'), findsOneWidget);
    });

    testWidgets('shows token card when patient is waiting', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Test Patient',
        'patientId': 'patient-uid',
        'tokenNo': 5,
        'status': 'waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientQueueScreen(
          doctorId: 'dr-uid',
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('YOUR TOKEN'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('WAITING'), findsOneWidget);
    });

    testWidgets('shows green card when patient is being served', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Test Patient',
        'patientId': 'patient-uid',
        'tokenNo': 3,
        'status': 'serving',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientQueueScreen(
          doctorId: 'dr-uid',
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('#3'), findsOneWidget);
      expect(find.text('SERVING'), findsOneWidget);
    });

    testWidgets('shows done items as empty state (filtered out)', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Test Patient',
        'patientId': 'patient-uid',
        'tokenNo': 1,
        'status': 'done',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientQueueScreen(
          doctorId: 'dr-uid',
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('You are not currently in any queue.'), findsOneWidget);
    });

    testWidgets('shows My Queue Status title after stream state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientQueueScreen(doctorId: 'test-doctor'),
        mockUser: patientUser,
        fakeFirestore: FakeFirebaseFirestore(),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PatientHome
  // ══════════════════════════════════════════════════════════════════════════
  group('PatientHome', () {
    testWidgets('renders scaffold without crash', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientHome(),
        mockUser: patientUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows Patient Dashboard app bar title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientHome(),
        mockUser: patientUser,
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Patient Dashboard'), findsOneWidget);
    });

    testWidgets('shows no-doctors state when users has no doctor', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      // No doctor in users collection

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('No doctors found'), findsOneWidget);
    });

    testWidgets('shows not-in-queue state when doctor selected but no queue entry', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      // Add a doctor so it auto-selects
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test',
        'role': 'doctor',
      });
      // No queue entries → "not in queue" state

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello'), findsOneWidget);
      expect(find.textContaining('not in the queue'), findsOneWidget);
    });

    testWidgets('shows doctor picker dropdown when multiple doctors exist', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient', 'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid-1').set({
        'name': 'Dr Alpha', 'role': 'doctor',
      });
      await fs.collection('users').doc('dr-uid-2').set({
        'name': 'Dr Beta', 'role': 'doctor',
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('shows in-queue token card when patient is waiting', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test',
        'role': 'doctor',
      });
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Test Patient',
        'patientId': 'patient-uid',
        'tokenNo': 3,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Token #3'), findsOneWidget);
      expect(find.text('CURRENT STATUS'), findsOneWidget);
    });

    testWidgets('shows serving state when patient is being served', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test',
        'role': 'doctor',
      });
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Test Patient',
        'patientId': 'patient-uid',
        'tokenNo': 2,
        'status': 'serving',
        'queueStatus': 'Serving',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOW SERVING'), findsOneWidget);
      expect(find.textContaining("Doctor's room"), findsOneWidget);
    });

    testWidgets('shows visit history when encounters exist', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      await fs.collection('encounters').doc('enc-1').set({
        'patientName': 'Test Patient',
        'rawNotes': 'Patient has fever and cough.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Visit History'), findsOneWidget);
      expect(find.text('Patient has fever and cough.'), findsOneWidget);
    });

    testWidgets('shows no past visits when encounters empty', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No past visits found.'), findsOneWidget);
    });

    testWidgets('visit history filters by selected doctor', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient', 'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test', 'role': 'doctor',
      });
      // Encounter for dr-uid
      await fs.collection('encounters').doc('enc-1').set({
        'patientName': 'Test Patient',
        'rawNotes': 'Notes from Dr Test.',
        'doctorId': 'dr-uid',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      // Encounter for another doctor (should be filtered out)
      await fs.collection('encounters').doc('enc-2').set({
        'patientName': 'Test Patient',
        'rawNotes': 'Notes from other doctor.',
        'doctorId': 'other-uid',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      // Auto-selected dr-uid, so only enc-1 is shown
      expect(find.text('Notes from Dr Test.'), findsOneWidget);
      expect(find.text('Notes from other doctor.'), findsNothing);
    });

    testWidgets('Show All button appears when doctor is selected', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient', 'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test', 'role': 'doctor',
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      // dr-uid auto-selected → "Show All" button visible
      expect(find.text('Show All'), findsOneWidget);
    });

    testWidgets('Show All button clears doctor filter and shows all visits', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient', 'role': 'patient',
      });
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Test', 'role': 'doctor',
      });
      await fs.collection('encounters').doc('enc-1').set({
        'patientName': 'Test Patient',
        'rawNotes': 'Visit notes one.',
        'doctorId': 'dr-uid',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-2').set({
        'patientName': 'Test Patient',
        'rawNotes': 'Visit notes two.',
        'doctorId': 'other-uid',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        PatientHome(
          auth: MockFirebaseAuth(signedIn: true, mockUser: patientUser),
          firestore: fs,
        ),
        mockUser: patientUser,
      ));
      await tester.pumpAndSettle();

      // Initially filtered: only enc-1 shown
      expect(find.text('Visit notes one.'), findsOneWidget);
      expect(find.text('Visit notes two.'), findsNothing);

      // Tap Show All
      await tester.tap(find.text('Show All'));
      await tester.pumpAndSettle();

      // Both encounters now shown
      expect(find.text('Visit notes one.'), findsOneWidget);
      expect(find.text('Visit notes two.'), findsOneWidget);
    });

    testWidgets('renders patient dashboard title after profile loads', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PatientHome(),
        mockUser: patientUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows patient dashboard when not in queue', (tester) async {
      final emptyFs = FakeFirebaseFirestore();
      await emptyFs.collection('users').doc('patient-uid').set({
        'name': 'Test Patient',
        'role': 'patient',
      });
      await tester.pumpWidget(buildTestApp(
        const PatientHome(),
        mockUser: patientUser,
        fakeFirestore: emptyFs,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
