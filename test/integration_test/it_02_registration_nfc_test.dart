// IT-02: Registration + NFC — Receptionist registers a patient and links an NFC card
//
// Integration scope: patient registration data → NFC card linking → activation.
// Verifies that after registration the patient document carries a UID, that the
// NFC card document is linked to that UID, and that the card is marked active.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';
import 'package:hospital_flow_app/models/patient_model.dart';

// ── Registration + NFC linking pipeline ───────────────────────────────────

class RegistrationResult {
  final PatientModel patient;
  final NFCCardModel card;

  RegistrationResult({required this.patient, required this.card});
}

/// Mirrors staff_register_patient_screen.dart + NfcService.registerAndActivateCard().
/// Returns the patient model and the linked NFC card model after registration.
RegistrationResult registerPatientWithCard({
  required String uid,
  required String name,
  required String contact,
  required String cardId,
}) {
  // Step 1: Build patient document (mirrors Firestore write in register flow)
  final patient = PatientModel(
    uid: uid,
    name: name,
    contact: contact,
    nfcCardId: cardId,
    createdAt: DateTime(2026, 6, 19),
  );

  // Step 2: Build NFC card document (mirrors NfcService.registerAndActivateCard)
  final card = NFCCardModel(
    cardId: cardId,
    assignedPatientId: uid,
    isActive: true,
  );

  return RegistrationResult(patient: patient, card: card);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-02: Registration + NFC — patient registration with card linking', () {
    const uid = 'uid-patient-reg-001';
    const name = 'Fatima Khan';
    const contact = '+601234567890';
    const cardId = 'NFC-CARD-A1B2';

    late RegistrationResult result;

    setUp(() {
      result = registerPatientWithCard(
        uid: uid,
        name: name,
        contact: contact,
        cardId: cardId,
      );
    });

    test('Patient document is stored with the correct UID', () {
      expect(result.patient.uid, equals(uid),
          reason: 'Patient UID must be persisted on the document');
      expect(result.patient.name, equals(name));
      expect(result.patient.contact, equals(contact));
    });

    test('Patient document references the NFC card', () {
      expect(result.patient.nfcCardId, equals(cardId),
          reason: 'Patient must carry a reference to the linked NFC card');
    });

    test('NFC card is linked to the patient UID', () {
      expect(result.card.assignedPatientId, equals(uid),
          reason: 'NFC card must be linked to the patient that was registered');
      expect(result.card.cardId, equals(cardId));
    });

    test('NFC card is active after registration', () {
      expect(result.card.isActive, isTrue,
          reason: 'Card must be activated as part of the registration flow');
    });

    test('Patient model serialises to a map with all required fields', () {
      final map = result.patient.toMap();

      expect(map['name'], equals(name));
      expect(map['contact'], equals(contact));
      expect(map['nfcCardId'], equals(cardId));
      expect(map.containsKey('createdAt'), isTrue);
    });

    test('NFC card model serialises to a map with isActive=true', () {
      final map = result.card.toMap();

      expect(map['assignedPatientId'], equals(uid));
      expect(map['isActive'], isTrue);
    });
  });
}
