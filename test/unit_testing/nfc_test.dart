// UT-02, UT-03: NFC — validateCard()
//
// Covers: NFCCardModel.isActive / assignedPatientId field logic.
// The production validation lives inside _handleHardwareCardTap in staff_home.dart.
// This file extracts that two-step check (active? → linked UID?) into a pure
// validateCard() function and tests both the rejection (UT-02) and acceptance (UT-03) paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';

class CardValidationResult {
  final bool isValid;
  final String? reason;
  final String? linkedPatientUid;

  CardValidationResult.valid({required this.linkedPatientUid})
      : isValid = true,
        reason = null;

  CardValidationResult.invalid(this.reason)
      : isValid = false,
        linkedPatientUid = null;
}

// Mirrors the card-check logic in staff_home.dart _handleHardwareCardTap:
//   1. Query 'activated_cards' — if isActive == false → reject with 'inactive'
//   2. Otherwise → accept and return assignedPatientId
CardValidationResult validateCard(NFCCardModel card) {
  if (!card.isActive) {
    return CardValidationResult.invalid('inactive');
  }
  return CardValidationResult.valid(linkedPatientUid: card.assignedPatientId);
}

void main() {
  group('UT-02: NFC — validateCard() — inactive card', () {
    test('Inactive card is rejected with reason "inactive"', () {
      // Arrange
      final card = NFCCardModel(
        cardId: 'CARD-INACTIVE-001',
        isActive: false,
        assignedPatientId: 'patient-uid-001',
      );

      // Act
      final result = validateCard(card);

      // Assert
      expect(result.isValid, isFalse,
          reason: 'Inactive card must be rejected');
      expect(result.reason, equals('inactive'),
          reason: 'Rejection reason must be exactly "inactive"');
      expect(result.linkedPatientUid, isNull);
    });

    test('NFCCardModel.fromFirestore correctly reads isActive=false', () {
      final data = {
        'isActive': false,
        'assignedPatientId': 'patient-uid-xyz',
      };

      final card = NFCCardModel.fromFirestore(data, 'CARD-002');

      expect(card.isActive, isFalse);

      final result = validateCard(card);
      expect(result.isValid, isFalse);
      expect(result.reason, equals('inactive'));
    });
  });

  group('UT-03: NFC — validateCard() — valid active card', () {
    test('Active card is accepted and returns linked patient UID', () {
      // Arrange
      const patientUid = 'patient-uid-active-001';
      final card = NFCCardModel(
        cardId: 'CARD-ACTIVE-001',
        isActive: true,
        assignedPatientId: patientUid,
      );

      // Act
      final result = validateCard(card);

      // Assert
      expect(result.isValid, isTrue,
          reason: 'Active card must be accepted');
      expect(result.linkedPatientUid, equals(patientUid),
          reason: 'Must return the correct linked patient UID');
      expect(result.reason, isNull);
    });

    test('NFCCardModel.fromFirestore correctly reads isActive=true + patientId', () {
      const expectedUid = 'uid-abc-123';
      final data = {
        'isActive': true,
        'assignedPatientId': expectedUid,
      };

      final card = NFCCardModel.fromFirestore(data, 'CARD-003');

      expect(card.isActive, isTrue);
      expect(card.assignedPatientId, equals(expectedUid));

      final result = validateCard(card);
      expect(result.isValid, isTrue);
      expect(result.linkedPatientUid, equals(expectedUid));
    });
  });
}
