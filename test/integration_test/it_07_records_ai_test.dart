// IT-07: Records + AI Summarization — Doctor saves notes then requests a summary
//
// Integration scope: note validation → encounter model creation (Records module)
// → note preprocessing → AI HTTP call (AI module) → summary linked to encounter.
//
// Verifies that the full flow from note entry to labelled, encounter-linked
// AI summary works correctly when the AI API responds successfully.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/encounter_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ── Shared constants ───────────────────────────────────────────────────────

const String kFlanPrefix = 'summarize medical transcription: ';
const int kAiInputMaxChars = 1024;

// ── Records module helpers ─────────────────────────────────────────────────

bool validateNote(String note) => note.trim().isNotEmpty;

EncounterModel buildEncounter({
  required String id,
  required String patientId,
  required String doctorId,
  required String notes,
}) {
  return EncounterModel(
    id: id,
    patientId: patientId,
    doctorId: doctorId,
    clinicalNotes: notes,
    timestamp: DateTime(2026, 6, 19, 10, 30),
  );
}

// ── AI module helpers ──────────────────────────────────────────────────────

String preprocessNote(String note) {
  final full = '$kFlanPrefix$note';
  return full.length <= kAiInputMaxChars ? full : full.substring(0, kAiInputMaxChars);
}

Future<String> callAI(String processedNote, http.Client client) async {
  final response = await client.post(
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

  if (response.statusCode != 200) {
    throw Exception('AI error (${response.statusCode})');
  }

  final result = jsonDecode(response.body) as List;
  final summary = (result[0]['generated_text'] as String?)?.trim();
  if (summary == null || summary.isEmpty) throw Exception('Empty summary');
  return summary;
}

// ── Summary record (links encounter → summary) ─────────────────────────────

class SummaryRecord {
  final String encounterId;
  final String summaryText;
  final String label;

  const SummaryRecord({
    required this.encounterId,
    required this.summaryText,
    required this.label,
  });
}

// ── Full pipeline ──────────────────────────────────────────────────────────

class RecordsAIResult {
  final EncounterModel encounter;
  final SummaryRecord summary;

  const RecordsAIResult({required this.encounter, required this.summary});
}

Future<RecordsAIResult> saveNotesAndGenerateSummary({
  required String encounterId,
  required String patientId,
  required String doctorId,
  required String rawNotes,
  required http.Client httpClient,
}) async {
  // Step 1: Records — validate note
  if (!validateNote(rawNotes)) {
    throw ArgumentError('Clinical note is empty');
  }

  // Step 2: Records — create encounter model
  final encounter = buildEncounter(
    id: encounterId,
    patientId: patientId,
    doctorId: doctorId,
    notes: rawNotes,
  );

  // Step 3: AI — preprocess
  final processed = preprocessNote(rawNotes);

  // Step 4: AI — generate summary
  final summaryText = await callAI(processed, httpClient);

  // Step 5: Link summary to encounter
  final summaryRecord = SummaryRecord(
    encounterId: encounterId,
    summaryText: summaryText,
    label: 'AI Clinical Summary',
  );

  return RecordsAIResult(encounter: encounter, summary: summaryRecord);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-07: Records + AI — doctor saves notes and requests a summary', () {
    const encounterId = 'enc-it07-001';
    const patientId = 'patient-uid-001';
    const doctorId = 'doctor@hospital.com';
    const rawNotes =
        'Patient presents with persistent cough for 5 days, mild fever 37.8°C, '
        'no chest pain. Prescribed amoxicillin 500mg TDS for 5 days.';

    const expectedSummary =
        'Patient has cough and mild fever. Prescribed amoxicillin.';

    late http.Client mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([{'generated_text': expectedSummary}]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    });

    test('Notes are stored with correct patient and doctor links', () async {
      final result = await saveNotesAndGenerateSummary(
        encounterId: encounterId,
        patientId: patientId,
        doctorId: doctorId,
        rawNotes: rawNotes,
        httpClient: mockClient,
      );

      final map = result.encounter.toMap();
      expect(map['patientId'], equals(patientId),
          reason: 'Encounter must be linked to the patient');
      expect(map['doctorId'], equals(doctorId),
          reason: 'Encounter must be linked to the doctor');
      expect(map['clinicalNotes'], equals(rawNotes));
    });

    test('AI summary is generated and is non-empty', () async {
      final result = await saveNotesAndGenerateSummary(
        encounterId: encounterId,
        patientId: patientId,
        doctorId: doctorId,
        rawNotes: rawNotes,
        httpClient: mockClient,
      );

      expect(result.summary.summaryText, isNotEmpty,
          reason: 'AI summary must not be empty');
      expect(result.summary.summaryText, equals(expectedSummary));
    });

    test('Summary is labelled and linked to the correct encounter ID', () async {
      final result = await saveNotesAndGenerateSummary(
        encounterId: encounterId,
        patientId: patientId,
        doctorId: doctorId,
        rawNotes: rawNotes,
        httpClient: mockClient,
      );

      expect(result.summary.encounterId, equals(encounterId),
          reason: 'Summary must be linked to the encounter');
      expect(result.summary.label, equals('AI Clinical Summary'),
          reason: 'Summary must carry the correct label');
    });

    test('Empty note is rejected before reaching the AI call', () async {
      expect(
        () => saveNotesAndGenerateSummary(
          encounterId: encounterId,
          patientId: patientId,
          doctorId: doctorId,
          rawNotes: '',
          httpClient: mockClient,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Empty note must be caught in the Records module',
      );
    });
  });
}
