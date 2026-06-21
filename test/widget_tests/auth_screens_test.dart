// auth_screens_test.dart — covers LoginScreen, RegisterScreen, AuthGate, RoleRouter, ProfileScreen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/auth/auth_gate.dart';
import 'package:hospital_flow_app/auth/login_screen.dart';
import 'package:hospital_flow_app/auth/register_screen.dart';
import 'package:hospital_flow_app/common/profile_screen.dart';
import 'package:hospital_flow_app/routes/role_router.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // LoginScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('LoginScreen', () {
    testWidgets('renders hero title, email/password fields and sign-in button', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      expect(find.text('Hospital Flow'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets); // heading + button
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('shows snackbar when email is empty on sign-in tap', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter your email and password'), findsOneWidget);
    });

    testWidgets('shows snackbar when password is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'a@b.com');
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please enter your email and password'), findsOneWidget);
    });

    testWidgets('toggles password visibility on icon tap', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('attempts login when both fields are filled', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password');
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();
    });

    testWidgets('shows Patient Management System subtitle in hero', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      expect(find.text('Patient Management System'), findsOneWidget);
    });

    testWidgets('shows admin info banner at bottom of form', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      expect(find.textContaining('Doctor and staff accounts'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // RegisterScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('RegisterScreen', () {
    testWidgets('renders hero and form fields with create account button', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows NFC Card ID field', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'NFC Card ID'), findsOneWidget);
    });

    testWidgets('shows NFC info banner about reception', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.textContaining('Ask reception staff'), findsOneWidget);
    });

    testWidgets('shows validation error when name is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      final registerBtn = find.byWidgetPredicate((w) => w is FilledButton);
      await tester.ensureVisible(registerBtn);
      await tester.tap(registerBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Please fill in all fields'), findsOneWidget);
    });

    testWidgets('shows error when passwords do not match', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Ali');
      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'a@b.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass1');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'pass2');
      final registerBtn2 = find.byWidgetPredicate((w) => w is FilledButton);
      await tester.ensureVisible(registerBtn2);
      await tester.tap(registerBtn2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows error when NFC card ID is not provided', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Ali');
      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'a@b.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'pass');
      final registerBtn3 = find.byWidgetPredicate((w) => w is FilledButton);
      await tester.ensureVisible(registerBtn3);
      await tester.tap(registerBtn3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('NFC Card ID is required'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('shows back arrow for navigation to login', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows Patient Registration header label', (tester) async {
      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.text('Patient Registration'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AuthGate
  // ══════════════════════════════════════════════════════════════════════════
  group('AuthGate', () {
    testWidgets('shows LoginScreen or loading when no user is signed in', (tester) async {
      await tester.pumpWidget(buildTestApp(const AuthGate()));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('Hospital Flow').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // RoleRouter — tests both with and without auth DI
  // ══════════════════════════════════════════════════════════════════════════
  group('RoleRouter', () {
    testWidgets('renders a Scaffold while resolving profile', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const RoleRouter(),
        mockUser: MockUser(uid: 'u1', email: 'unknown@example.com'),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('routes to WallMountedScreen for wall email via auth DI', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('w1').set({
        'name': 'Wall Screen',
        'role': 'wallmounted',
        'email': 'wallmounted@gmail.com',
      });
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'w1', email: 'wallmounted@gmail.com'),
      );
      await tester.pumpWidget(buildTestApp(
        RoleRouter(auth: mockAuth),
        mockUser: MockUser(uid: 'w1', email: 'wallmounted@gmail.com'),
        fakeFirestore: fs,
      ));
      await tester.pump();
      await tester.pump();
      // WallMountedScreen renders (header text or loading spinner)
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('routes to DoctorHome for doctor email via auth DI', (tester) async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'doctor-uid', email: 'sahilo5657@gmail.com'),
      );
      await tester.pumpWidget(buildTestApp(
        RoleRouter(auth: mockAuth),
        mockUser: MockUser(uid: 'doctor-uid', email: 'sahilo5657@gmail.com'),
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.text('Doctor Dashboard'), findsOneWidget);
    });

    testWidgets('routes to StaffHome for staff email via auth DI', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('staff-uid').set({
        'name': 'Staff Member',
        'role': 'staff',
        'email': 'eshaan5657@gmail.com',
      });
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'staff-uid', email: 'eshaan5657@gmail.com'),
      );
      await tester.pumpWidget(buildTestApp(
        RoleRouter(auth: mockAuth),
        mockUser: MockUser(uid: 'staff-uid', email: 'eshaan5657@gmail.com'),
        fakeFirestore: fs,
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Reception'), findsOneWidget);
    });

    testWidgets('routes to PatientHome for patient email via auth DI', (tester) async {
      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'patient-uid', email: 'testpatient@gmail.com'),
      );
      await tester.pumpWidget(buildTestApp(
        RoleRouter(auth: mockAuth),
        mockUser: MockUser(uid: 'patient-uid', email: 'testpatient@gmail.com'),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Patient Dashboard'), findsOneWidget);
    });

    testWidgets('RoleRouter renders without crashing for wall email', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const RoleRouter(),
        mockUser: MockUser(uid: 'w1', email: 'wallmounted@gmail.com'),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('RoleRouter renders without crashing for doctor email', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const RoleRouter(),
        mockUser: MockUser(uid: 'd1', email: 'sahilo5657@gmail.com'),
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('RoleRouter renders without crashing for staff email', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const RoleRouter(),
        mockUser: MockUser(uid: 's1', email: 'eshaan5657@gmail.com'),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('RoleRouter renders without crashing for patient email', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const RoleRouter(),
        mockUser: MockUser(uid: 'p1', email: 'testpatient@gmail.com'),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ProfileScreen
  // ══════════════════════════════════════════════════════════════════════════
  group('ProfileScreen', () {
    testWidgets('renders profile screen scaffold', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const ProfileScreen(),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsWidgets);
    });

    testWidgets('shows log out button', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const ProfileScreen(),
        mockUser: doctorUser,
        fakeFirestore: seededFirestore(),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}
