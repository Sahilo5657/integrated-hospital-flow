// UT-12, UT-13: AI — preprocess()/chunk() and generateSummary() wrapper
//
// UT-12: Note longer than the model's input limit is truncated, with
//        a truncation flag set. Flan-T5-base accepts ≈512 tokens; 1 024 chars
//        is used as a conservative character-level proxy.
//
// UT-13: Given a valid processed note, the HuggingFace API wrapper returns
//        a non-empty summary string. HTTP is mocked so no live call is made.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart'; // MockClient — bundled with the http package

// ── Constants ──────────────────────────────────────────────────────────────

// Flan-T5-base max input ≈ 512 tokens ≈ 1 024 characters (safe proxy).
const int kAiInputMaxChars = 1024;

// Prefix applied in AISummaryService — must stay in sync with production code.
const String kFlanPrefix = 'summarize medical transcription: ';

// ── Preprocessing logic ────────────────────────────────────────────────────

typedef PreprocessResult = ({String text, bool wasTruncated});

/// Prepends the Flan-T5 task prefix and truncates to [maxChars] if needed.
PreprocessResult preprocessNote(String note, {int maxChars = kAiInputMaxChars}) {
  final full = '$kFlanPrefix$note';
  if (full.length <= maxChars) {
    return (text: full, wasTruncated: false);
  }
  return (text: full.substring(0, maxChars), wasTruncated: true);
}

// ── HTTP call + response parsing (mirrors AISummaryService.getSummary) ─────

/// Calls the HuggingFace inference API and parses the generated_text field.
/// Accepts an injectable [client] so tests can substitute a MockClient.
Future<String> generateSummaryViaHF(
  String processedNote,
  http.Client client, {
  String apiUrl = 'https://api-inference.huggingface.co/models/test',
  String token = 'test-token',
}) async {
  final response = await client.post(
    Uri.parse(apiUrl),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'x-wait-for-model': 'true',
    },
    body: jsonEncode({
      'inputs': processedNote,
      'parameters': {'max_new_tokens': 128, 'do_sample': false},
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('AI API error (${response.statusCode}): ${response.body}');
  }

  final result = jsonDecode(response.body) as List;
  final summary = (result[0]['generated_text'] as String?)?.trim();

  if (summary == null || summary.isEmpty) {
    throw Exception('AI returned an empty summary');
  }
  return summary;
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // UT-12 ──────────────────────────────────────────────────────────────────
  group('UT-12: AI — preprocess()/chunk()', () {
    test('Note longer than model limit is truncated and truncation flag is set', () {
      // Arrange: note that would exceed the char limit after prefix is added
      final longNote = 'A' * (kAiInputMaxChars + 500);

      // Act
      final result = preprocessNote(longNote);

      // Assert
      expect(result.text.length, lessThanOrEqualTo(kAiInputMaxChars),
          reason: 'Output must be within the model character limit');
      expect(result.wasTruncated, isTrue,
          reason: 'Truncation flag must be set when input is over limit');
    });

    test('Short note is not truncated and flag is false', () {
      const shortNote = 'Patient has mild headache.';

      final result = preprocessNote(shortNote);

      expect(result.text.length, lessThanOrEqualTo(kAiInputMaxChars));
      expect(result.wasTruncated, isFalse,
          reason: 'Short note must not set the truncation flag');
      expect(result.text, contains(shortNote),
          reason: 'Processed text must include the original note');
      expect(result.text, startsWith(kFlanPrefix),
          reason: 'Flan-T5 task prefix must be prepended');
    });

    test('Note that makes prefixed string exactly maxChars is NOT truncated', () {
      // A note exactly long enough to reach the boundary (inclusive)
      final noteAtLimit = 'B' * (kAiInputMaxChars - kFlanPrefix.length);

      final result = preprocessNote(noteAtLimit);

      expect(result.wasTruncated, isFalse,
          reason: 'Boundary case: exactly at limit must not truncate');
      expect(result.text.length, equals(kAiInputMaxChars));
    });

    test('Note one character over the boundary IS truncated', () {
      final noteOverLimit = 'C' * (kAiInputMaxChars - kFlanPrefix.length + 1);

      final result = preprocessNote(noteOverLimit);

      expect(result.wasTruncated, isTrue);
      expect(result.text.length, equals(kAiInputMaxChars));
    });
  });

  // UT-13 ──────────────────────────────────────────────────────────────────
  group('UT-13: AI — generateSummary() wrapper', () {
    test('Valid processed note returns non-empty summary string', () async {
      // Arrange: mock client returns a well-formed Flan-T5 response
      const expectedSummary =
          'Patient presents with hypertension and mild chest discomfort.';

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([{'generated_text': expectedSummary}]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      const processedNote =
          'summarize medical transcription: Patient has high BP and chest pain.';

      // Act
      final summary = await generateSummaryViaHF(processedNote, mockClient);

      // Assert
      expect(summary, isNotEmpty, reason: 'Summary must not be empty');
      expect(summary, equals(expectedSummary),
          reason: 'Must return the generated_text field from the API response');
    });

    test('API 503 response throws an exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Model is loading', 'estimated_time': 20}),
          503,
        );
      });

      expect(
        () => generateSummaryViaHF('some note', mockClient),
        throwsException,
      );
    });

    test('Empty generated_text in response throws an exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([{'generated_text': ''}]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      expect(
        () => generateSummaryViaHF('some note', mockClient),
        throwsException,
      );
    });
  });
}
