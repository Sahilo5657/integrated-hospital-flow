// doctor_history_screens_test.dart
// Covers DoctorPatientListScreen and DoctorPatientHistoryScreen —
// two screens that were added after the initial test suite was written.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/doctor/doctor_patient_history_screen.dart';
import 'package:hospital_flow_app/doctor/doctor_patient_list_screen.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorPatientListScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorPatientListScreen', () {
    testWidgets('renders Patient History title in AppBar', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientListScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
        fakeFirestore: FakeFirebaseFirestore(),
      ));
      await tester.pump();
      expect(find.text('Patient History'), findsOneWidget);
    });

    testWidgets('shows scaffold while loading from singleton Firestore', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientListScreen(doctorId: 'dr-test'),
        mockUser: doctorUser,
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows empty state when no encounters exist for this doctor', (tester) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();
      expect(find.text('No patient history yet.'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('shows patient entry with visit count when one encounter exists', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-a1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Alice',
        'patientId': 'p1',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('1 visit · Last: 20/6/2026'), findsOneWidget);
    });

    testWidgets('groups multiple encounters by the same patient name', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-b1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Bob',
        'patientId': 'p2',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-b2').set({
        'doctorId': 'dr-uid',
        'patientName': 'Bob',
        'patientId': 'p2',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 10, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // Bob appears once with visit count 2; last visit date is the later one
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('2 visits · Last: 20/6/2026'), findsOneWidget);
    });

    testWidgets('skips encounters where patientName is empty — no tiles rendered', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-empty-name').set({
        'doctorId': 'dr-uid',
        'patientName': '',
        'patientId': 'p3',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // docs is non-empty but the empty-name entry is skipped → no patient tiles rendered
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows multiple distinct patients as separate list tiles', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-c1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Carol',
        'patientId': 'p4',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 18, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-d1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Dave',
        'patientId': 'p5',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
    });

    testWidgets('shows chevron_right icon for each patient tile', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-e1').set({
        'doctorId': 'dr-uid',
        'patientName': 'Eve',
        'patientId': 'p6',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('encounter without timestamp shows dash for last visit date', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-no-ts').set({
        'doctorId': 'dr-uid',
        'patientName': 'Frank No Date',
        'patientId': 'p7',
        // No timestamp field
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientListScreen(doctorId: 'dr-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Frank No Date'), findsOneWidget);
      expect(find.text('1 visit · Last: —'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorPatientHistoryScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorPatientHistoryScreen', () {
    testWidgets('renders patient name as AppBar title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientHistoryScreen(
          patientName: 'John Doe',
          patientId: 'p1',
        ),
        mockUser: doctorUser,
        fakeFirestore: FakeFirebaseFirestore(),
      ));
      await tester.pump();
      expect(find.text('John Doe'), findsWidgets);
    });

    testWidgets('shows scaffold while waiting for singleton Firestore', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const DoctorPatientHistoryScreen(
          patientName: 'Loading Patient',
          patientId: 'p-load',
        ),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows empty state when patient has no visit history', (tester) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'No History Patient',
          patientId: 'p-empty',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();
      expect(find.text('No visit history for this patient.'), findsOneWidget);
    });

    testWidgets('shows visit card with rawNotes when encounter exists', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-raw').set({
        'patientName': 'Jane Test',
        'patientId': 'p1',
        'rawNotes': 'Patient has high blood pressure.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 30)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Jane Test',
          patientId: 'p1',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Patient has high blood pressure.'), findsOneWidget);
      expect(find.text("Doctor's Notes"), findsOneWidget);
    });

    testWidgets('shows No notes recorded when rawNotes field is empty string', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-nonotes').set({
        'patientName': 'Empty Notes',
        'patientId': 'p-no',
        'rawNotes': '',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 10, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Empty Notes',
          patientId: 'p-no',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No notes recorded.'), findsOneWidget);
    });

    testWidgets('uses clinicalNotes as fallback when rawNotes field is absent', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-clin').set({
        'patientName': 'Clinical Fallback',
        'patientId': 'p-clin',
        'clinicalNotes': 'Patient has diabetes mellitus.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Clinical Fallback',
          patientId: 'p-clin',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Patient has diabetes mellitus.'), findsOneWidget);
    });

    testWidgets('shows AI summary box when aiSummary field is a valid summary', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-ai').set({
        'patientName': 'AI Patient',
        'patientId': 'p-ai',
        'rawNotes': 'Patient has chest pain.',
        'aiSummary': 'Chest pain, suspected angina. Referred to cardiologist.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'AI Patient',
          patientId: 'p-ai',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('AI Summary'), findsWidgets);
      expect(
        find.text('Chest pain, suspected angina. Referred to cardiologist.'),
        findsOneWidget,
      );
    });

    testWidgets('does NOT show AI summary box when aiSummary starts with failure prefix', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-fail').set({
        'patientName': 'Fail Patient',
        'patientId': 'p-fail',
        'rawNotes': 'Some notes.',
        'aiSummary': 'Summary generation failed: timeout',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Fail Patient',
          patientId: 'p-fail',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // Failed AI text must NOT appear in the AI summary box
      expect(find.text('Summary generation failed: timeout'), findsNothing);
    });

    testWidgets('shows Generate AI Summary button with plural visit label', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-btn1').set({
        'patientName': 'Button Test',
        'patientId': 'p-btn',
        'rawNotes': 'First visit notes.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-btn2').set({
        'patientName': 'Button Test',
        'patientId': 'p-btn',
        'rawNotes': 'Second visit notes.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Button Test',
          patientId: 'p-btn',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Generate AI Summary'), findsOneWidget);
      expect(find.textContaining('2 visits'), findsOneWidget);
    });

    testWidgets('shows singular "visit" label when only one encounter exists', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-single').set({
        'patientName': 'Single Visit',
        'patientId': 'p-single',
        'rawNotes': 'One visit.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Single Visit',
          patientId: 'p-single',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // Button label must say "1 visit)" (not "1 visits)")
      expect(find.textContaining('1 visit)'), findsOneWidget);
    });

    testWidgets('opens AI summary dialog when Generate AI Summary button is tapped', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-dlg').set({
        'patientName': 'Dialog Patient',
        'patientId': 'p-dlg',
        'rawNotes': 'Fever and cough.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Dialog Patient',
          patientId: 'p-dlg',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Generate AI Summary'));
      await tester.pump();
      await tester.pump();

      // AlertDialog is shown with the correct title
      expect(find.text('Generate AI Summary'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('AI summary dialog shows patient name and visit count in subtitle', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-hdr').set({
        'patientName': 'Header Patient',
        'patientId': 'p-hdr',
        'rawNotes': 'Notes here.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Header Patient',
          patientId: 'p-hdr',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Generate AI Summary'));
      await tester.pump();
      await tester.pump();

      // Dialog subtitle shows patient name and visit count
      expect(find.textContaining('Header Patient'), findsWidgets);
      expect(find.textContaining('1 visit'), findsWidgets);
    });

    testWidgets('Close button in AI dialog dismisses the dialog', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-close').set({
        'patientName': 'Close Test',
        'patientId': 'p-close',
        'rawNotes': 'Close test notes.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Close Test',
          patientId: 'p-close',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Generate AI Summary'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog is dismissed — Close button gone
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('visit card shows date dash when encounter has no timestamp', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-nots').set({
        'patientName': 'No Timestamp Patient',
        'patientId': 'p-nots',
        'rawNotes': 'Notes without timestamp.',
        // No timestamp field
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'No Timestamp Patient',
          patientId: 'p-nots',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // Date in the visit card header shows "—" when timestamp is absent
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('visit cards show newest first when multiple encounters exist', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('encounters').doc('enc-old').set({
        'patientName': 'Multi Visit',
        'patientId': 'p-multi',
        'rawNotes': 'Older visit notes.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 10, 9, 0)),
      });
      await fs.collection('encounters').doc('enc-new').set({
        'patientName': 'Multi Visit',
        'patientId': 'p-multi',
        'rawNotes': 'Newer visit notes.',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        DoctorPatientHistoryScreen(
          patientName: 'Multi Visit',
          patientId: 'p-multi',
          firestore: fs,
        ),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // Both visits rendered
      expect(find.text('Older visit notes.'), findsOneWidget);
      expect(find.text('Newer visit notes.'), findsOneWidget);
      // Visit count button label with plural
      expect(find.textContaining('2 visits'), findsOneWidget);
    });
  });
}
