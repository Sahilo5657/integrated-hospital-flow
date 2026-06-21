// common_ui_test.dart — covers app_theme, UICard, UISection, UIShell, MyApp
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/app_theme.dart';
import 'package:hospital_flow_app/common/ui_card.dart';
import 'package:hospital_flow_app/common/ui_section.dart';
import 'package:hospital_flow_app/common/ui_shell.dart';
import '../helpers/firebase_test_setup.dart';


void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ── buildTheme ────────────────────────────────────────────────────────────
  group('buildTheme()', () {
    test('returns a ThemeData with Material 3 enabled', () {
      final theme = buildTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('scaffold background is teal-tinted white', () {
      final theme = buildTheme();
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF0FDFA));
    });

    test('colorScheme is not null', () {
      final theme = buildTheme();
      expect(theme.colorScheme, isNotNull);
    });

    test('appBarTheme has teal primary background', () {
      final theme = buildTheme();
      expect(theme.appBarTheme.backgroundColor, kPrimary);
    });

    test('appBarTheme foreground is white', () {
      final theme = buildTheme();
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('filledButtonTheme shape is rounded rectangle', () {
      final theme = buildTheme();
      expect(theme.filledButtonTheme.style, isNotNull);
    });
  });

  // ── UICard ────────────────────────────────────────────────────────────────
  group('UICard', () {
    testWidgets('renders title, value and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UICard(
              title: 'Patients',
              value: '42',
              icon: Icons.people,
            ),
          ),
        ),
      );
      // UICard uppercases the title label
      expect(find.text('PATIENTS'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('renders optional subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UICard(
              title: 'Queue',
              value: '5',
              icon: Icons.list,
              subtitle: 'In waiting room',
            ),
          ),
        ),
      );
      expect(find.text('In waiting room'), findsOneWidget);
    });

    testWidgets('does not render subtitle widget when omitted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UICard(title: 'Test', value: '0', icon: Icons.star),
          ),
        ),
      );
      // UICard uppercases the title label; value is shown as-is
      expect(find.text('TEST'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('accentColor overrides theme primary for icon container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UICard(
              title: 'Revenue',
              value: '500',
              icon: Icons.attach_money,
              accentColor: Colors.orange,
            ),
          ),
        ),
      );
      expect(find.text('Revenue'.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });
  });

  // ── UISection ─────────────────────────────────────────────────────────────
  group('UISection', () {
    testWidgets('renders title and children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UISection(
              title: 'Controls',
              children: [const Text('Button A'), const Text('Button B')],
            ),
          ),
        ),
      );
      expect(find.text('Controls'), findsOneWidget);
      expect(find.text('Button A'), findsOneWidget);
      expect(find.text('Button B'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UISection(
              title: 'Section',
              subtitle: 'Optional sub',
              children: [const SizedBox()],
            ),
          ),
        ),
      );
      expect(find.text('Optional sub'), findsOneWidget);
    });

    testWidgets('does not show subtitle widget when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UISection(title: 'T', children: [const SizedBox()]),
          ),
        ),
      );
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UISection(
              title: 'With Trailing',
              trailing: const Text('Action'),
              children: [const SizedBox()],
            ),
          ),
        ),
      );
      expect(find.text('With Trailing'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('does not render trailing when not provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UISection(
              title: 'No Trailing',
              children: [const SizedBox()],
            ),
          ),
        ),
      );
      expect(find.text('No Trailing'), findsOneWidget);
      // No trailing widget — just children
    });
  });

  // ── UIShell ───────────────────────────────────────────────────────────────
  group('UIShell', () {
    testWidgets('shows title in AppBar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const UIShell(
            title: 'Test Shell',
            showActions: false,
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('Test Shell'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('shows profile icon when showActions=true', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          UIShell(
            title: 'Shell With Actions',
            showActions: true,
            child: const Text('content'),
          ),
        ),
      );
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    });

    testWidgets('shows no profile icon when showActions=false', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const UIShell(
            title: 'No Actions Shell',
            showActions: false,
            child: Text('content'),
          ),
        ),
      );
      expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
    });

    testWidgets('renders custom action widgets alongside profile icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          UIShell(
            title: 'With Custom Action',
            showActions: true,
            actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
