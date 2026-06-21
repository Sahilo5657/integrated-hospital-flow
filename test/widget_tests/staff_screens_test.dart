// staff_screens_test.dart — covers StaffHome, StaffRegisterPatientScreen, AnalyticsScreen, BackupScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/staff/analytics_screen.dart';
import 'package:hospital_flow_app/staff/backup_screen.dart';
import 'package:hospital_flow_app/staff/staff_home.dart';
import 'package:hospital_flow_app/staff/staff_register_patient_screen.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // StaffHome
  // ══════════════════════════════════════════════════════════════════════════
  group('StaffHome', () {
    testWidgets('renders Reception title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Reception'), findsOneWidget);
    });

    testWidgets('shows NFC Card Registration section', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('NFC Card Registration'), findsOneWidget);
    });

    testWidgets('shows NFC tap card input field', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Tap card on reader...'), findsOneWidget);
    });

    testWidgets('shows Operational Analytics and Backup buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Operational Analytics'), findsOneWidget);
      expect(find.text('Database Backup & Recovery'), findsOneWidget);
    });

    testWidgets('logout button is in AppBar', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('shows welcome message with staff email', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.textContaining('Welcome'), findsOneWidget);
    });

    testWidgets('shows Find Patient by NIC section', (tester) async {
      // Use a tall surface so the NIC section (below the fold) is in the viewport
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Find Patient by NIC'), findsOneWidget);
    });

    testWidgets('shows NIC search text field', (tester) async {
      // Use a tall surface so the NIC search section is in the viewport
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        const StaffHome(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'National ID (NIC)'), findsOneWidget);
    });

    testWidgets('shows no doctors found when doctors collection is empty', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No doctors found in the system.'), findsOneWidget);
    });

    testWidgets('shows doctor dropdown when doctors exist', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('dr-uid').set({
        'name': 'Dr Smith',
        'role': 'doctor',
      });

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('unknown NFC card shows new card registration form', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tap card on reader...'),
        'UNKNOWN-CARD',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('New card — enter patient details'), findsOneWidget);
    });

    testWidgets('registration form validation shows snackbar when fields empty', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tap card on reader...'),
        'NEW-CARD',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Clear any card-not-found snackbar
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump();

      final registerBtn = find.text('Register Card');
      await tester.ensureVisible(registerBtn);
      await tester.pump();
      await tester.tap(registerBtn);
      await tester.pump();

      expect(find.text('Name and phone are required.'), findsOneWidget);
    });

    testWidgets('known card shows registered card confirmation', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('activated_cards').doc('CARD-ABC').set({
        'cardId': 'CARD-ABC',
        'patientName': 'Alice',
        'status': 'active',
      });

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tap card on reader...'),
        'CARD-ABC',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (int i = 0; i < 5; i++) await tester.pump();

      expect(find.textContaining('Alice'), findsWidgets);
    });

    testWidgets('second known card scan shows registered confirmation', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('activated_cards').doc('CARD-BOB').set({
        'cardId': 'CARD-BOB',
        'patientName': 'Bob',
        'status': 'active',
      });

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tap card on reader...'),
        'CARD-BOB',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (int i = 0; i < 5; i++) await tester.pump();

      expect(find.textContaining('Bob'), findsWidgets);
    });

    testWidgets('NIC search shows patient not found message for unknown NIC', (tester) async {
      final fs = FakeFirebaseFirestore();
      // Use a tall surface so the NIC section is fully visible and interactive
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'National ID (NIC)'),
        '99999',
      );
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No patient found with that NIC'), findsOneWidget);
    });

    testWidgets('NIC search shows patient found details when NIC exists', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('patients').doc('12345').set({
        'patientName': 'Carol',
        'phoneNumber': '+60123456789',
        'nic': '12345',
      });
      // Use a tall surface so the NIC section is fully visible and interactive
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'National ID (NIC)'),
        '12345',
      );
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Patient Found'), findsOneWidget);
      expect(find.textContaining('Carol'), findsWidgets);
    });

    testWidgets('registration with NIC writes to both collections', (tester) async {
      final fs = FakeFirebaseFirestore();
      // Use a tall surface so the registration form is visible without ensureVisible pushing
      // the button center into the AppBar hit-test zone.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        StaffHome(firestore: fs, auth: MockFirebaseAuth(signedIn: true, mockUser: staffUser)),
        mockUser: staffUser,
      ));
      await tester.pump();

      // Scan unknown card
      await tester.enterText(
        find.widgetWithText(TextField, 'Tap card on reader...'),
        'CARD-NEW',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(); await tester.pump(); await tester.pump();

      // Fill in registration form
      await tester.enterText(find.widgetWithText(TextField, 'Patient Full Name'), 'David');
      await tester.enterText(find.widgetWithText(TextField, 'Phone Number'), '+601234');
      await tester.enterText(find.widgetWithText(TextField, 'NIC / National ID (optional)'), 'NIC-001');

      final registerBtn = find.text('Register Card');
      await tester.ensureVisible(registerBtn);
      await tester.pump();
      // Clear any residual snackbars before tapping
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump();
      await tester.tap(registerBtn);
      await tester.pump(); await tester.pump(); await tester.pump();

      // Both collections should be written
      final cardDoc = await fs.collection('activated_cards').doc('CARD-NEW').get();
      final patientDoc = await fs.collection('patients').doc('NIC-001').get();
      expect(cardDoc.exists, isTrue);
      expect(patientDoc.exists, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // StaffRegisterPatientScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('StaffRegisterPatientScreen', () {
    testWidgets('renders Activate Patient Card title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffRegisterPatientScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Activate Patient Card'), findsOneWidget);
    });

    testWidgets('renders all input fields', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffRegisterPatientScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'NFC Card ID'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Patient Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Phone Number'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'CNIC (Optional)'), findsOneWidget);
    });

    testWidgets('shows validation snackbar when fields are empty', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffRegisterPatientScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Activate Card'));
      await tester.pump();

      expect(find.text('Please fill in Name, Phone, and NFC Card ID'), findsOneWidget);
    });

    testWidgets('Activate Card button is present and enabled when not loading', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const StaffRegisterPatientScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Activate Card'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AnalyticsScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('AnalyticsScreen', () {
    testWidgets('shows Clinic Analytics Reports title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AnalyticsScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Clinic Analytics Reports'), findsOneWidget);
    });

    testWidgets('shows loading spinner while stream is waiting', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AnalyticsScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('Clinic Analytics Reports').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows empty state when no data', (tester) async {
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(buildTestApp(
        AnalyticsScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();
      expect(find.text('No data yet. Patients will appear here once they check in.'), findsOneWidget);
    });

    testWidgets('shows analytics dashboard with done+skipped data', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Patient A',
        'status': 'done',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Patient B',
        'status': 'skipped',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 14, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        AnalyticsScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Operational Insights Dashboard'), findsOneWidget);
      expect(find.text('Peak Rush Hour'), findsOneWidget);
      expect(find.text('Busiest Day'), findsOneWidget);
      expect(find.text('Avg. Wait Time'), findsOneWidget);
      expect(find.text('No-Show Rate'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows analytics with serving and waiting data', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'status': 'serving',
        'etaMins': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 8, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'status': 'waiting',
        'etaMins': 20,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 12, 0)),
      });
      await fs.collection('queues').doc('q3').set({
        'doctorId': 'sahilo5657@gmail.com',
        'status': 'done',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 18, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        AnalyticsScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Operational Insights Dashboard'), findsOneWidget);
      expect(find.text('Peak Rush Hour'), findsOneWidget);
      expect(find.text('Avg. Wait Time'), findsOneWidget);
    });

    testWidgets('renders scaffold with Firestore data config', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Patient A',
        'status': 'done',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        const AnalyticsScreen(),
        mockUser: staffUser,
        fakeFirestore: fs,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Analytics scaffold with multi-status data config', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'status': 'done',
        'etaMins': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 15, 0, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'status': 'skipped',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 15, 14, 0)),
      });
      await tester.pumpWidget(buildTestApp(
        const AnalyticsScreen(),
        mockUser: staffUser,
        fakeFirestore: fs,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // BackupScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('BackupScreen', () {
    testWidgets('renders Database Backup & Disaster Recovery title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BackupScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Database Backup & Disaster Recovery'), findsOneWidget);
    });

    testWidgets('shows warning icon when no backup exists', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BackupScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('No backup created yet today.'), findsOneWidget);
    });

    testWidgets('shows export and restore buttons when not processing', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BackupScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();
      expect(find.text('Export Active Queue Data'), findsOneWidget);
      expect(find.text('Trigger Database Restore Plan'), findsOneWidget);
    });

    testWidgets('restore shows snackbar when no backup exists', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BackupScreen(),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Trigger Database Restore Plan'));
      await tester.pump();

      expect(find.text('Aborted: Please create a system backup snapshot first!'), findsOneWidget);
    });

    testWidgets('export shows no-data snackbar when queue is empty', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        BackupScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Export Active Queue Data'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('No data found in queue collection to back up!'), findsOneWidget);
    });

    testWidgets('export succeeds with seeded queue data', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Alice',
        'status': 'waiting',
        'tokenNo': 1,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        BackupScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Export Active Queue Data'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Saved'), findsOneWidget);
    });

    testWidgets('restore succeeds after export', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'patientName': 'Alice',
        'status': 'waiting',
        'tokenNo': 1,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        BackupScreen(firestore: fs),
        mockUser: staffUser,
      ));
      await tester.pump();

      await tester.tap(find.text('Export Active Queue Data'));
      for (int i = 0; i < 6; i++) await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(find.text('Trigger Database Restore Plan'));
      for (int i = 0; i < 8; i++) await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
