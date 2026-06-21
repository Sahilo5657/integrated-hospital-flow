// IT-04: Queue + Duplicate Prevention — Same patient taps twice
//
// Integration scope: NFC card validation → duplicate check → token assignment,
// called twice for the same patient. Verifies that the second tap does not
// create a new queue entry and instead surfaces the existing position.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Stateful queue simulation ──────────────────────────────────────────────

class TapResult {
  final bool isNewEntry;
  final int tokenNo;
  final String message;

  TapResult.newEntry(this.tokenNo)
      : isNewEntry = true,
        message = 'Token $tokenNo assigned';

  TapResult.existing(this.tokenNo)
      : isNewEntry = false,
        message = 'Already in queue at position $tokenNo';
}

/// Simulates the full NFC-tap → queue-check flow.
/// [queue] is mutated on a new entry (mirrors Firestore write in staff_home).
TapResult handleCardTap({
  required NFCCardModel card,
  required String patientId,
  required String patientName,
  required List<QueueItem> queue,
}) {
  // NFC validation
  if (!card.isActive) {
    return TapResult.existing(-1); // card rejected — no token
  }

  // Duplicate prevention: active (waiting/serving) entry for same patient?
  final existing = queue.where(
    (item) =>
        item.patientId == patientId &&
        (item.status == QueueStatus.waiting ||
            item.status == QueueStatus.serving),
  );

  if (existing.isNotEmpty) {
    return TapResult.existing(existing.first.tokenNo);
  }

  // Assign next token
  final nextToken = queue.isEmpty
      ? 1
      : queue.map((e) => e.tokenNo).reduce((a, b) => a > b ? a : b) + 1;

  // Append to queue (simulates Firestore add)
  queue.add(QueueItem(
    id: 'doc-$nextToken',
    tokenNo: nextToken,
    patientName: patientName,
    patientId: patientId,
    etaMins: 15,
    status: QueueStatus.waiting,
    timestamp: DateTime.now(),
  ));

  return TapResult.newEntry(nextToken);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-04: Queue + Duplicate Prevention — same patient taps twice', () {
    final card = NFCCardModel(
      cardId: 'CARD-DUPE-001',
      isActive: true,
      assignedPatientId: 'uid-patient-dupe',
    );

    const patientId = 'uid-patient-dupe';
    const patientName = 'Ahmed';

    test('First tap creates a queue entry and assigns a token', () {
      final queue = <QueueItem>[];

      final firstTap = handleCardTap(
        card: card,
        patientId: patientId,
        patientName: patientName,
        queue: queue,
      );

      expect(firstTap.isNewEntry, isTrue,
          reason: 'First tap must create a new queue entry');
      expect(firstTap.tokenNo, equals(1));
      expect(queue.length, equals(1),
          reason: 'Queue must have exactly one entry after first tap');
    });

    test('Second tap returns existing position; no new entry created', () {
      final queue = <QueueItem>[];

      // First tap
      handleCardTap(
        card: card,
        patientId: patientId,
        patientName: patientName,
        queue: queue,
      );

      final queueLengthAfterFirst = queue.length;

      // Second tap — same patient
      final secondTap = handleCardTap(
        card: card,
        patientId: patientId,
        patientName: patientName,
        queue: queue,
      );

      expect(secondTap.isNewEntry, isFalse,
          reason: 'Second tap must be recognised as a duplicate');
      expect(secondTap.tokenNo, equals(1),
          reason: 'Existing token number must be returned');
      expect(queue.length, equals(queueLengthAfterFirst),
          reason: 'Queue length must not increase on a duplicate tap');
    });

    test('Different patient can still join after first patient is queued', () {
      final queue = <QueueItem>[];

      // Patient A taps
      handleCardTap(
        card: card,
        patientId: patientId,
        patientName: patientName,
        queue: queue,
      );

      // Patient B taps with a different card
      final cardB = NFCCardModel(
        cardId: 'CARD-B',
        isActive: true,
        assignedPatientId: 'uid-patient-B',
      );

      final tapB = handleCardTap(
        card: cardB,
        patientId: 'uid-patient-B',
        patientName: 'Sara',
        queue: queue,
      );

      expect(tapB.isNewEntry, isTrue);
      expect(tapB.tokenNo, equals(2));
      expect(queue.length, equals(2));
    });

    test('Patient who has "done" status can tap again and get a new token', () {
      final queue = <QueueItem>[
        QueueItem(
          id: 'doc-1',
          tokenNo: 1,
          patientName: patientName,
          patientId: patientId,
          etaMins: 15,
          status: QueueStatus.done, // already served
          timestamp: DateTime.now(),
        ),
      ];

      final result = handleCardTap(
        card: card,
        patientId: patientId,
        patientName: patientName,
        queue: queue,
      );

      expect(result.isNewEntry, isTrue,
          reason: 'Completed patient must be allowed to re-join');
      expect(result.tokenNo, equals(2));
    });
  });
}
