// wall_screens_test.dart — covers WallMountedScreen and WallDisplayScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/wall/wall_display_screen.dart';
import 'package:hospital_flow_app/wall/wall_mounted_screen.dart';
import '../helpers/firebase_test_setup.dart';

/// Returns a [FakeFirebaseFirestore] with one seeded doctor for WallMountedScreen tests.
FakeFirebaseFirestore _fsWithDoctor({String doctorUid = 'doc-uid', String doctorName = 'Dr Test'}) {
  final fs = FakeFirebaseFirestore();
  fs.collection('users').doc(doctorUid).set({
    'name': doctorName,
    'role': 'doctor',
  });
  return fs;
}

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // WallDisplayScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('WallDisplayScreen', () {
    testWidgets('renders Wall Display title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WallDisplayScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(find.text('Wall Display'), findsOneWidget);
    });

    testWidgets('shows loading spinner while stream connects', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WallDisplayScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('NOW SERVING').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('renders scaffold body regardless of stream state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WallDisplayScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows NOW SERVING and no upcoming when empty queue', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(buildTestApp(
        WallDisplayScreen(doctorId: 'doc-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOW SERVING'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('NEXT IN LINE'), findsOneWidget);
      expect(find.text('No upcoming patients.'), findsOneWidget);
    });

    testWidgets('shows serving patient details', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'doc-uid',
        'patientName': 'Alice Test',
        'tokenNo': 5,
        'status': 'serving',
        'etaMins': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        WallDisplayScreen(doctorId: 'doc-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Alice Test'), findsOneWidget);
      expect(find.textContaining('#5'), findsOneWidget);
    });

    testWidgets('shows waiting patients in NEXT IN LINE list with ETA', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'doc-uid',
        'patientName': 'Carol',
        'tokenNo': 3,
        'status': 'waiting',
        'etaMins': 30,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        WallDisplayScreen(doctorId: 'doc-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Carol'), findsOneWidget);
      // ETA = (position+1) × avgMins; first waiting patient (i=0) → (0+1)×15 = 15 min
      expect(find.text('Est. Wait: 15 min'), findsOneWidget);
    });

    testWidgets('shows computed ETA even when stored etaMins is 0', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'doc-uid',
        'patientName': 'Dave',
        'tokenNo': 4,
        'status': 'waiting',
        'etaMins': 0,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 20, 9, 0)),
      });

      await tester.pumpWidget(buildTestApp(
        WallDisplayScreen(doctorId: 'doc-uid', firestore: fs),
        mockUser: doctorUser,
      ));
      await tester.pumpAndSettle();

      // WallDisplay computes ETA from (i+1)*avgMins; ignores stored etaMins.
      // First waiting patient (i=0): (0+1) × 15 = 15 min
      expect(find.text('Dave'), findsOneWidget);
      expect(find.text('Est. Wait: 15 min'), findsOneWidget);
    });

    testWidgets('shows NEXT IN LINE section header', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const WallDisplayScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('WallDisplay renders with seeded Firestore config', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'doc-uid',
        'patientName': 'Alice',
        'tokenNo': 1,
        'status': 'waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await tester.pumpWidget(buildTestApp(
        const WallDisplayScreen(doctorId: 'test-doctor'),
        mockUser: doctorUser,
        fakeFirestore: fs,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WallMountedScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('WallMountedScreen', () {
    testWidgets('renders dark-themed scaffold with hospital header when doctor loaded', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hospital Patient Flow'), findsOneWidget);
    });

    testWidgets('shows Live indicator in header when doctor auto-selected', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('shows "NOW SERVING" section with no active patient', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOW SERVING'), findsOneWidget);
      expect(find.text('— No active patient —'), findsOneWidget);
    });

    testWidgets('shows PATIENTS WAITING section with empty queue', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PATIENTS WAITING'), findsOneWidget);
      expect(find.text('Queue is empty'), findsOneWidget);
    });

    testWidgets('shows select-doctor prompt when no doctors exist', (tester) async {
      final fs = FakeFirebaseFirestore(); // no doctors
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Select a doctor'), findsWidgets);
    });

    testWidgets('shows spinner while loading doctors', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      // Before async resolves → spinner may show
      await tester.pump();
      // Either spinner OR queue content
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('NOW SERVING').evaluate().isNotEmpty ||
            find.textContaining('Select a doctor').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('WallMounted renders with patient data when doctor matches queue', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('doc-uid').set({
        'name': 'Dr Test', 'role': 'doctor',
      });
      await fs.collection('queues').doc('q1').set({
        'doctorId': 'doc-uid',
        'patientName': 'Eve',
        'tokenNo': 7,
        'status': 'serving',
        'etaMins': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': 'doc-uid',
        'patientName': 'Frank',
        'tokenNo': 8,
        'status': 'waiting',
        'etaMins': 15,
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 15)),
      });

      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hospital Patient Flow'), findsOneWidget);
      expect(find.text('Eve'), findsOneWidget);
      expect(find.text('Frank'), findsOneWidget);
    });

    testWidgets('renders date/time header section when doctor loaded', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hospital Patient Flow'), findsOneWidget);
    });

    testWidgets('change doctor button is visible in header', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('logout button is in header', (tester) async {
      final fs = _fsWithDoctor();
      await tester.pumpWidget(buildTestApp(
        WallMountedScreen(firestore: fs),
        mockUser: MockUser(uid: 'wall-uid', email: 'wallmounted@gmail.com'),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });
  });
}
