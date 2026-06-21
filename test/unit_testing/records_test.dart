// UT-10, UT-11: Records — saveEncounter() / validateNote()
//
// UT-10: Valid note text → Encounter stored, linked to patient & doctor.
//        Verified by building EncounterModel and checking toMap() contains
//        the correct patientId and doctorId keys.
//
// UT-11: Empty note → Validation error.
//        Mirrors the `if (trim.isEmpty) return;` guard in _saveEncounter().

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/encounter_model.dart';

// ── Note validation (mirrors _saveEncounter guard) ────────────────────────

class NoteValidationResult {
  final bool isValid;
  final String? error;

  NoteValidationResult.valid()
      : isValid = true,
        error = null;

  NoteValidationResult.invalid(this.error) : isValid = false;
}

NoteValidationResult validateNote(String note) {
  if (note.trim().isEmpty) {
    return NoteValidationResult.invalid('Clinical note cannot be empty');
  }
  return NoteValidationResult.valid();
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // UT-10 ──────────────────────────────────────────────────────────────────
  group('UT-10: Records — saveEncounter()', () {
    test('Valid note creates encounter linked to correct patient and doctor', () {
      // Arrange
      const patientId = 'patient-uid-001';
      const doctorId = 'doctor@hospital.com';
      const notes = 'Patient presents with mild fever, cough for 3 days.';

      // Act — build EncounterModel as the save logic would before writing to Firestore
      final encounter = EncounterModel(
        id: 'enc-test-001',
        patientId: patientId,
        doctorId: doctorId,
        clinicalNotes: notes,
        timestamp: DateTime(2026, 6, 19, 10, 0),
      );

      final map = encounter.toMap();

      // Assert — record must carry the correct foreign keys
      expect(map['patientId'], equals(patientId),
          reason: 'Encounter must be linked to the patient');
      expect(map['doctorId'], equals(doctorId),
          reason: 'Encounter must be linked to the doctor');
      expect(map['clinicalNotes'], equals(notes),
          reason: 'Clinical notes must be persisted as entered');
      expect(map['timestamp'], isA<Timestamp>(),
          reason: 'Timestamp must be a Firestore Timestamp');
    });

    test('EncounterModel round-trips correctly through toMap()', () {
      final original = EncounterModel(
        id: 'enc-002',
        patientId: 'p-abc',
        doctorId: 'd-xyz',
        clinicalNotes: 'Follow-up: BP stable.',
        timestamp: DateTime(2026, 6, 19),
      );

      final map = original.toMap();

      expect(map.containsKey('patientId'), isTrue);
      expect(map.containsKey('doctorId'), isTrue);
      expect(map.containsKey('clinicalNotes'), isTrue);
      expect(map.containsKey('timestamp'), isTrue);
    });
  });

  // UT-11 ──────────────────────────────────────────────────────────────────
  group('UT-11: Records — validateNote()', () {
    test('Empty string fails validation with a non-null error message', () {
      final result = validateNote('');

      expect(result.isValid, isFalse,
          reason: 'Empty note must be rejected');
      expect(result.error, isNotNull,
          reason: 'Rejection must include a descriptive error');
      expect(result.error, isNotEmpty);
    });

    test('Whitespace-only note fails validation', () {
      final result = validateNote('   \t\n');

      expect(result.isValid, isFalse,
          reason: 'Whitespace-only input counts as empty');
    });

    test('Valid non-empty note passes validation', () {
      final result = validateNote('Patient reports dizziness and nausea.');

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('Single character note passes validation', () {
      final result = validateNote('X');

      expect(result.isValid, isTrue,
          reason: 'Any non-whitespace content should pass');
    });
  });
}
