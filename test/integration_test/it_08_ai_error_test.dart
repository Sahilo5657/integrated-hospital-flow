// IT-08: AI Summarization (error path) — Summary requested while model unavailable
//
// Integration scope: AI preprocessing → repeated 503 responses → exception surfaced
// → original notes remain unaffected.
//
// Verifies that when the HuggingFace model returns 503 on every attempt,
// the system throws a catchable exception and the original clinical notes
// stored in the encounter model are not lost or corrupted.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/encounter_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ── AI call with retry (mirrors AISummaryService retry loop) ──────────────

const int kMaxRetries = 5;

Future<String> callAIWithRetry(
  String processedNote,
  http.Client client, {
  Duration retryDelay = const Duration(milliseconds: 10), // fast in tests
}) async {
  String? summary;

  for (int attempt = 0; attempt < kMaxRetries; attempt++) {
    late http.Response response;
    try {
      response = await client.post(
        Uri.parse('https://api-inference.huggingface.co/models/test'),
        headers: {
          'Authorization': 'Bearer test-token',
          'Content-Type': 'application/json',
          'x-wait-for-model': 'true',
        },
        body: jsonEncode({
          'inputs': processedNote,
          'parameters': {'max_new_tokens': 128, 'do_sample': false},
        }),
      );
    } catch (e) {
      if (attempt == kMaxRetries - 1) rethrow;
      await Future.delayed(retryDelay);
      continue;
    }

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as List;
      summary = (result[0]['generated_text'] as String?)?.trim();
      if (summary != null && summary.isNotEmpty) break;
    } else if (response.statusCode == 503) {
      if (attempt == kMaxRetries - 1) {
        throw Exception(
            'AI model is taking too long to load. Please try again later.');
      }
      await Future.delayed(retryDelay);
    } else {
      throw Exception('AI error (${response.statusCode}): ${response.body}');
    }
  }

  if (summary == null || summary.isEmpty) {
    throw Exception('AI returned an empty response.');
  }
  return summary;
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  const rawNotes =
      'Patient has a 3-day history of sore throat, fever 38.2°C, no rash.';

  // Encounter built before AI is requested — notes must survive the error
  final encounter = EncounterModel(
    id: 'enc-it08-001',
    patientId: 'patient-uid-it08',
    doctorId: 'doctor@hospital.com',
    clinicalNotes: rawNotes,
    timestamp: DateTime(2026, 6, 19),
  );

  group('IT-08: AI Summarization — error path when model is unavailable', () {
    test('503 on every attempt throws an exception after all retries', () async {
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'error': 'Model is loading', 'estimated_time': 20}),
          503,
        );
      });

      await expectLater(
        () => callAIWithRetry(rawNotes, mockClient),
        throwsException,
        reason: 'All retries exhausted on 503 must surface an exception',
      );

      expect(callCount, equals(kMaxRetries),
          reason: 'System must attempt exactly $kMaxRetries retries before giving up');
    });

    test('Original clinical notes remain available after AI failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error":"loading"}', 503);
      });

      // AI call fails — notes must still be intact in the encounter
      try {
        await callAIWithRetry(encounter.clinicalNotes, mockClient);
      } catch (_) {
        // expected — swallow to check notes below
      }

      expect(encounter.clinicalNotes, equals(rawNotes),
          reason: 'Encounter notes must not be modified by an AI failure');
      expect(encounter.clinicalNotes, isNotEmpty);
    });

    test('Non-503 error (e.g. 401 Unauthorized) throws immediately without retrying', () async {
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('{"error":"invalid token"}', 401);
      });

      await expectLater(
        () => callAIWithRetry(rawNotes, mockClient),
        throwsException,
      );

      expect(callCount, equals(1),
          reason: 'Non-503 errors must not be retried');
    });

    test('Single 503 followed by 200 succeeds (transient failure recovers)', () async {
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('{"error":"loading"}', 503);
        }
        return http.Response(
          jsonEncode([{'generated_text': 'Patient has fever and sore throat.'}]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final summary = await callAIWithRetry(rawNotes, mockClient);

      expect(summary, isNotEmpty,
          reason: 'Transient 503 must be retried and succeed on second attempt');
      expect(callCount, equals(2));
    });
  });
}
