// IT-05: Queue + Daily Limit — Tap when daily limit reached
//
// Integration scope: NFC validation → daily-limit check → check-in rejection.
// Verifies that the system correctly rejects a new tap when the queue is at
// capacity and returns a 'limit reached' message to be shown to the patient.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const int kDailyPatientLimit = 20; // mirrors _kDailyPatientLimit in staff_home.dart

// ── Check-in pipeline ─────────────────────────────────────────────────────

class CheckInResult {
  final bool accepted;
  final String message;
  final int? tokenNo;

  CheckInResult.accepted(this.tokenNo)
      : accepted = true,
        message = 'Token $tokenNo assigned';

  CheckInResult.rejected(this.message)
      : accepted = false,
        tokenNo = null;
}

CheckInResult attemptCheckIn({
  required NFCCardModel card,
  required String patientId,
  required String patientName,
  required List<QueueItem> todayQueue,
}) {
  // NFC validation
  if (!card.isActive) {
    return CheckInResult.rejected('Card inactive');
  }

  // Daily limit check (mirrors _isDailyLimitReached in staff_home.dart)
  if (todayQueue.length >= kDailyPatientLimit) {
    return CheckInResult.rejected('limit reached');
  }

  // Duplicate check
  final alreadyActive = todayQueue.any(
    (item) =>
        item.patientId == patientId &&
        (item.status == QueueStatus.waiting ||
            item.status == QueueStatus.serving),
  );
  if (alreadyActive) {
    final existing = todayQueue
        .firstWhere((item) => item.patientId == patientId)
        .tokenNo;
    return CheckInResult.rejected('Already in queue at token $existing');
  }

  // Assign token
  final nextToken = todayQueue.isEmpty
      ? 1
      : todayQueue.map((e) => e.tokenNo).reduce((a, b) => a > b ? a : b) + 1;

  return CheckInResult.accepted(nextToken);
}

// ── Helpers ────────────────────────────────────────────────────────────────

NFCCardModel _activeCard(String id, String patientId) =>
    NFCCardModel(cardId: id, isActive: true, assignedPatientId: patientId);

List<QueueItem> _buildQueue(int count) => List.generate(
      count,
      (i) => QueueItem(
        id: 'doc-${i + 1}',
        tokenNo: i + 1,
        patientName: 'Patient-$i',
        patientId: 'pid-$i',
        etaMins: 15,
        status: QueueStatus.waiting,
        timestamp: DateTime.now(),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-05: Queue + Daily Limit — tap rejected when capacity is reached', () {
    final newCard = _activeCard('CARD-NEW', 'uid-new-patient');

    test('Check-in rejected exactly at daily limit (20 patients)', () {
      final fullQueue = _buildQueue(kDailyPatientLimit); // 20 items

      final result = attemptCheckIn(
        card: newCard,
        patientId: 'uid-new-patient',
        patientName: 'Late Patient',
        todayQueue: fullQueue,
      );

      expect(result.accepted, isFalse,
          reason: 'Must reject when queue count equals the daily limit');
      expect(result.message, contains('limit reached'),
          reason: 'Rejection message must say "limit reached"');
      expect(result.tokenNo, isNull);
    });

    test('Check-in accepted one below the daily limit (19 patients)', () {
      final almostFullQueue = _buildQueue(kDailyPatientLimit - 1); // 19 items

      final result = attemptCheckIn(
        card: newCard,
        patientId: 'uid-new-patient',
        patientName: 'Last Patient',
        todayQueue: almostFullQueue,
      );

      expect(result.accepted, isTrue,
          reason: 'Must accept when one slot remains below the limit');
      expect(result.tokenNo, equals(kDailyPatientLimit),
          reason: 'Token must equal the daily limit value (20th slot)');
    });

    test('Check-in rejected above the daily limit (21 patients already)', () {
      // Edge: queue somehow exceeds 20 (e.g. written directly to Firestore)
      final overLimitQueue = _buildQueue(kDailyPatientLimit + 1);

      final result = attemptCheckIn(
        card: newCard,
        patientId: 'uid-new-patient',
        patientName: 'Extra Patient',
        todayQueue: overLimitQueue,
      );

      expect(result.accepted, isFalse);
      expect(result.message, contains('limit reached'));
    });

    test('Empty queue always accepts a check-in', () {
      final result = attemptCheckIn(
        card: newCard,
        patientId: 'uid-new-patient',
        patientName: 'First Patient',
        todayQueue: [],
      );

      expect(result.accepted, isTrue);
      expect(result.tokenNo, equals(1));
    });
  });
}
