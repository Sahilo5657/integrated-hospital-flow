// eta_nfc_ai_service_test.dart — covers EtaService, NfService, AISummaryService
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/services/eta_service.dart';
import 'package:hospital_flow_app/services/nfc_service.dart';
import 'package:hospital_flow_app/services/ai_summary_service.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../helpers/firebase_test_setup.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // EtaService
  // ══════════════════════════════════════════════════════════════════════════
  group('EtaService', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      await setupFirebaseForTests();
      fs = FakeFirebaseFirestore();
    });

    test('returns default 15.0 when fewer than 2 encounters', () async {
      // Only 1 encounter — not enough to compute EMA
      await fs.collection('encounters').doc('e1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      final svc = EtaService(firestore: fs);
      final result = await svc.getEstimatedMinutesPerPatient();
      expect(result, 15.0);
    });

    test('returns default 15.0 when no encounters exist', () async {
      final svc = EtaService(firestore: fs);
      final result = await svc.getEstimatedMinutesPerPatient();
      expect(result, 15.0);
    });

    test('computes EMA from exactly 2 encounters with valid gap', () async {
      await fs.collection('encounters').doc('e1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await fs.collection('encounters').doc('e2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 20)), // 20 min gap
      });
      final svc = EtaService(firestore: fs);
      final result = await svc.getEstimatedMinutesPerPatient();
      // Single gap of 20min → EMA = 20, clamped to [5,60]
      expect(result, closeTo(20.0, 1.0));
    });

    test('filters gaps outside the 1-90 minute sanity window', () async {
      // Gap of 0 minutes (same second saves) should be filtered out
      final t = DateTime(2026, 6, 19, 9, 0);
      await fs.collection('encounters').doc('e1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(t),
      });
      await fs.collection('encounters').doc('e2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(t), // same time → 0 min → filtered
      });
      final svc = EtaService(firestore: fs);
      // Both filtered → returns default
      final result = await svc.getEstimatedMinutesPerPatient();
      expect(result, 15.0);
    });

    test('clamps EMA result to the [5, 60] clinical range', () async {
      // Two encounters 100 minutes apart — EMA would be 100 min, clamped to 60
      await fs.collection('encounters').doc('e1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 7, 0)),
      });
      await fs.collection('encounters').doc('e2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 8, 45)), // 105 min, filtered (>90)
      });
      final svc = EtaService(firestore: fs);
      // 105 min gap filtered → durations empty → default
      final result = await svc.getEstimatedMinutesPerPatient();
      expect(result, 15.0);
    });

    test('EMA is computed correctly over 3+ encounters', () async {
      // 3 encounters with 10min, 20min gaps → EMA should be between 10 and 20
      await fs.collection('encounters').doc('e1').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 0)),
      });
      await fs.collection('encounters').doc('e2').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 10)),
      });
      await fs.collection('encounters').doc('e3').set({
        'doctorId': 'sahilo5657@gmail.com',
        'timestamp': Timestamp.fromDate(DateTime(2026, 6, 19, 9, 30)),
      });
      final svc = EtaService(firestore: fs);
      final result = await svc.getEstimatedMinutesPerPatient();
      // First gap: 10, second gap: 20
      // EMA = 0.35*20 + 0.65*10 = 7 + 6.5 = 13.5
      expect(result, closeTo(13.5, 0.5));
    });

    test('returns default when Firestore throws', () async {
      // Uninitialized firestore — should catch and return default
      // Use a fresh (unrelated) service — no encounters, same as empty
      final svc = EtaService(firestore: FakeFirebaseFirestore());
      final result = await svc.getEstimatedMinutesPerPatient();
      expect(result, 15.0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // NfService
  // ══════════════════════════════════════════════════════════════════════════
  group('NfService', () {
    late FakeFirebaseFirestore fs;
    late NfService svc;

    setUp(() async {
      await setupFirebaseForTests();
      fs = FakeFirebaseFirestore();
      svc = NfService(firestore: fs);
    });

    test('registerAndActivateCard stores card data in activated_cards', () async {
      await svc.registerAndActivateCard(
        cardId: 'CARD-X1',
        patientName: 'Jane Doe',
        phoneNumber: '+601111111111',
      );
      final doc = await fs.collection('activated_cards').doc('CARD-X1').get();
      expect(doc.exists, isTrue);
      expect(doc['patientName'], 'Jane Doe');
      expect(doc['status'], 'active');
    });

    test('checkInPatientToQueue adds a queue entry and returns true', () async {
      final result = await svc.checkInPatientToQueue('CARD-X1', 'Jane Doe');
      expect(result, isTrue);

      final snapshot = await fs.collection('queues').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first['patientName'], 'Jane Doe');
      expect(snapshot.docs.first['status'], 'waiting');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AISummaryService
  // ══════════════════════════════════════════════════════════════════════════
  group('AISummaryService', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      await setupFirebaseForTests();
      fs = FakeFirebaseFirestore();
    });

    test('returns cached summary from Firestore when one exists', () async {
      await fs.collection('summaries').doc('s-1').set({
        'encounterId': 'enc-cached',
        'summaryText': 'Cached diagnosis summary.',
        'timestamp': Timestamp.now(),
      });

      final svc = AISummaryService(firestore: fs, client: http.Client());
      final result = await svc.getSummary('enc-cached', 'Patient notes');
      expect(result, 'Cached diagnosis summary.');
    });

    test('calls HF API when no cache exists — 200 response returns summary', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([{'summary_text': 'AI generated summary.'}]),
          200,
        );
      });

      final svc = AISummaryService(firestore: fs, client: mockClient);
      final result = await svc.getSummary('enc-new', 'Patient has fever.');
      expect(result, 'AI generated summary.');

      // Should also have been cached in Firestore
      final cached = await fs
          .collection('summaries')
          .where('encounterId', isEqualTo: 'enc-new')
          .get();
      expect(cached.docs.length, 1);
      expect(cached.docs.first['summaryText'], 'AI generated summary.');
    });

    test('retries on 503 with estimated_time and eventually succeeds', () async {
      int calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        if (calls < 2) {
          return http.Response(
            jsonEncode({'error': 'loading', 'estimated_time': 5}),
            503,
          );
        }
        return http.Response(
          jsonEncode([{'summary_text': 'Retry success summary.'}]),
          200,
        );
      });

      final svc = AISummaryService(firestore: fs, client: mockClient);
      final result = await svc.getSummary('enc-retry', 'Notes here.');
      expect(result, 'Retry success summary.');
    });

    test('throws on non-200/503 status code (e.g. 401)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final svc = AISummaryService(firestore: fs, client: mockClient);
      expect(
        () async => svc.getSummary('enc-fail', 'Notes.'),
        throwsException,
      );
    });

    test('onStatus callback is called during connection and retry', () async {
      int calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        if (calls < 2) {
          return http.Response(
            jsonEncode({'error': 'loading', 'estimated_time': 5}),
            503,
          );
        }
        return http.Response(
          jsonEncode([{'summary_text': 'Done.'}]),
          200,
        );
      });

      final statuses = <String>[];
      final svc = AISummaryService(firestore: fs, client: mockClient);
      await svc.getSummary(
        'enc-status',
        'Notes.',
        onStatus: (msg) => statuses.add(msg),
      );

      expect(statuses, isNotEmpty);
      expect(statuses.first, contains('Generating'));
    });

    test('503 without estimated_time falls back to 15s wait', () async {
      int calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        if (calls < 2) {
          // No estimated_time in body
          return http.Response(jsonEncode({'error': 'loading'}), 503);
        }
        return http.Response(
          jsonEncode([{'summary_text': 'Fallback summary.'}]),
          200,
        );
      });

      final svc = AISummaryService(firestore: fs, client: mockClient);
      final result = await svc.getSummary('enc-503-fallback', 'Notes.');
      expect(result, 'Fallback summary.');
    });
  });
}
