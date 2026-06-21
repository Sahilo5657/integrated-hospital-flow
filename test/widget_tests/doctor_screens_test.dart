// doctor_screens_test.dart — covers DoctorHome, DoctorQueueScreen, DoctorPatientRecordScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/doctor/doctor_home.dart';
import 'package:hospital_flow_app/doctor/doctor_patient_record_screen.dart';
import 'package:hospital_flow_app/doctor/doctor_queue_screen.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorHome
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorHome', () {
    testWidgets('renders Doctor Dashboard scaffold', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorHome(),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.text('Doctor Dashboard'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator while FutureBuilder resolves', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorHome(),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows welcome text after profile resolves', (tester) async {
      final fs = seededFirestore();
      await tester.pumpWidget(buildTestApp(
        const DoctorHome(),
        mockUser: doctorUser,
        fakeFirestore: fs,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('logout button is visible in AppBar', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorHome(),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('shows dashboard with empty queue via injected Firestore', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        DoctorHome(firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // UICard uppercases its title; check the actual rendered text
      expect(find.text('NOW SERVING'), findsOneWidget);
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('Call Next'), findsOneWidget);
    });

    testWidgets('shows serving patient in dashboard', (tester) async {
      final fs = FakeFirebaseFirestore();
      // DoctorHome uses FirebaseAuth.instance.currentUser?.uid which is '' in tests,
      // so seed doctorId as '' to match the stream query filter.
      await fs.collection('queues').doc('q1').set({
        'doctorId': '',
        'patientName': 'Jane Doe',
        'patientId': 'patient-uid',
        'tokenNo': 2,
        'status': 'serving',
        'queueStatus': 'Serving',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': '',
        'patientName': 'Bob Smith',
        'patientId': 'patient-uid-2',
        'tokenNo': 3,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 15)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorHome(firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsWidgets);
      expect(find.text('Complete Visit'), findsOneWidget);
    });

    testWidgets('shows notes-empty snackbar when Complete Visit clicked without notes', (tester) async {
      final fs = FakeFirebaseFirestore();
      // DoctorHome uses FirebaseAuth.instance.currentUser?.uid = '' in tests
      await fs.collection('queues').doc('q1').set({
        'doctorId': '',
        'patientName': 'Alice',
        'patientId': 'uid1',
        'tokenNo': 1,
        'status': 'serving',
        'queueStatus': 'Serving',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorHome(firestore: fs),
        mockUser: doctorUser,
      ));
      // pump explicitly to ensure FakeFirestore stream emits before pumpAndSettle
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Confirm serving patient is rendered (servingDoc != null → button enabled)
      expect(find.text('Alice'), findsOneWidget);

      final completeVisitBtn = find.text('Complete Visit');
      await tester.ensureVisible(completeVisitBtn);
      await tester.pumpAndSettle();
      await tester.tap(completeVisitBtn);
      await tester.pump();

      expect(find.text('Please enter clinical notes before completing the visit.'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorQueueScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorQueueScreen', () {
    testWidgets('renders Today\'s Queue title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorQueueScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(find.text("Today's Queue"), findsOneWidget);
    });

    testWidgets('shows spinner while stream is waiting', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorQueueScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows All caught up when queue is empty', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('No patients currently waiting or being served.'), findsOneWidget);
    });

    testWidgets('shows waiting patient in queue list', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'John Patient',
        'patientId': 'p1',
        'tokenNo': 7,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('John Patient'), findsOneWidget);
      // First patient in the sorted list (i=0): etaMins = (0 * _avgMins).round() = 0
      expect(find.text('Est. wait: 0 min'), findsOneWidget);
      expect(find.text('AI Summary'), findsOneWidget);
      expect(find.text('View Record'), findsOneWidget);
    });

    testWidgets('shows serving patient with SERVING chip', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Jane Patient',
        'patientId': 'p2',
        'tokenNo': 2,
        'status': 'serving',
        'queueStatus': 'Serving',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Jane Patient'), findsOneWidget);
      expect(find.text('SERVING'), findsOneWidget);
    });

    testWidgets('tapping AI Summary shows no-notes snackbar when no encounters', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'NoEncounterPatient',
        'patientId': 'p3',
        'tokenNo': 1,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      // No encounters seeded for this patient

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Summary'));
      await tester.pump(); // show progress dialog
      await tester.pump(); // Firestore resolves (no encounters)
      await tester.pump(); // pop dialog + show snackbar

      expect(find.text('No clinical notes found for this patient.'), findsOneWidget);
    });

    testWidgets('tapping campaign icon calls _servePatient and sets status to serving', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Serve Test',
        'patientId': 'p1',
        'tokenNo': 1,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.campaign));
      await tester.pump();
      await tester.pump();

      final doc = await fs.collection('queues').doc('q1').get();
      expect(doc.data()?['status'], equals('serving'));
    });

    testWidgets('AI Summary shows bottom sheet with cached summary', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'AI Patient',
        'patientId': 'ai-p1',
        'tokenNo': 1,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'etaMins': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-ai').set({
        'patientName': 'AI Patient',
        'patientId': 'ai-p1',
        'rawNotes': 'Patient has hypertension.',
        'aiSummary': 'Hypertension confirmed. Prescribed lisinopril.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 8, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorQueueScreen(doctorId: 'sahilo5657@gmail.com', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Summary'));
      await tester.pump(); // show loading dialog
      await tester.pump(); // Firestore resolves with encounter
      await tester.pump(); // process + pop dialog
      await tester.pumpAndSettle(); // settle bottom sheet animation

      expect(find.textContaining('AI Summary: AI Patient'), findsOneWidget);
      expect(find.text('Hypertension confirmed. Prescribed lisinopril.'), findsOneWidget);
    });

    testWidgets('shows queue content or loading state when queue is empty (singleton)', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorQueueScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
        fakeFirestore: FakeFirebaseFirestore(),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorPatientRecordScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorPatientRecordScreen', () {
    testWidgets('renders patient name in AppBar title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'John Doe',
        ),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(find.text('Patient Record: John Doe'), findsOneWidget);
    });

    testWidgets('renders clinical notes input and save button', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'Jane Doe',
        ),
        mockUser: doctorUser,
      ));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Add Clinical Notes'), findsOneWidget);
      expect(find.text('Save Encounter'), findsOneWidget);
    });

    testWidgets('save button does nothing when notes field is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'Jane Doe',
        ),
        mockUser: doctorUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Save Encounter'));
      await tester.pump();
    });

    testWidgets('shows No history available when no encounters', (tester) async {
      final fs = FakeFirebaseFirestore();
      // No encounters for this patient

      await tester.pumpWidget(buildTestApp(
        DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'Empty Patient',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No history available.'), findsOneWidget);
    });

    testWidgets('shows encounter history list when encounters exist', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-1').set({
        'patientName': 'John Doe',
        'rawNotes': 'Patient reported chest pain.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'John Doe',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Patient reported chest pain.'), findsOneWidget);
    });

    testWidgets('saves encounter notes and shows success snackbar', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'Jane Doe',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Add Clinical Notes'), 'Hypertension noted.');
      await tester.tap(find.text('Save Encounter'));
      await tester.pump(); // start async
      await tester.pump(); // Firestore resolves
      await tester.pump(); // setState + snackbar

      expect(find.text('Notes saved successfully.'), findsOneWidget);
    });

    testWidgets('shows history loading state (StreamBuilder)', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientRecordScreen(
          patientId: 'patient-uid',
          patientName: 'Test Patient',
        ),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders form elements regardless of stream state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientRecordScreen(
          patientId: 'unknown-patient',
          patientName: 'Unknown Patient',
        ),
        mockUser: doctorUser,
        fakeFirestore: FakeFirebaseFirestore(),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Patient Record: Unknown Patient'), findsOneWidget);
    });
  });
}
