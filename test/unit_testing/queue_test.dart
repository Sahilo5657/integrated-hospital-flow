// UT-04, UT-05, UT-06, UT-07: Queue logic
//
// Covers: assignToken, preventDuplicate, checkDailyLimit, fifoOrder.
// Production logic lives across auth_service.dart (joinQueue/callNext) and
// staff_home.dart (_isDailyLimitReached, _getNextTokenNumber, _handleHardwareCardTap).
// This file distils those rules into pure functions that can be tested without Firebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const int kDailyPatientLimit = 20; // matches _kDailyPatientLimit in staff_home.dart

// ── Pure business-logic helpers ────────────────────────────────────────────

class TokenAssignResult {
  final bool success;
  final int? tokenNo;
  final String? rejectionReason; // 'duplicate' | 'limit_reached'
  final int? existingTokenNo;   // set when rejectionReason == 'duplicate'

  TokenAssignResult._success(this.tokenNo)
      : success = true,
        rejectionReason = null,
        existingTokenNo = null;

  TokenAssignResult._duplicate(this.existingTokenNo)
      : success = false,
        tokenNo = null,
        rejectionReason = 'duplicate';

  TokenAssignResult._limitReached()
      : success = false,
        tokenNo = null,
        rejectionReason = 'limit_reached',
        existingTokenNo = null;
}

/// Mirrors the joinQueue() logic in auth_service.dart +
/// the card-tap checks in staff_home.dart.
TokenAssignResult assignToken({
  required List<QueueItem> existingQueue,
  required String patientId,
  required String patientName,
}) {
  // preventDuplicate: reject if patient already has an active entry
  final duplicate = existingQueue.where(
    (item) =>
        item.patientId == patientId &&
        (item.status == QueueStatus.waiting ||
            item.status == QueueStatus.serving),
  );
  if (duplicate.isNotEmpty) {
    return TokenAssignResult._duplicate(duplicate.first.tokenNo);
  }

  // checkDailyLimit: reject when at or above the daily cap
  if (existingQueue.length >= kDailyPatientLimit) {
    return TokenAssignResult._limitReached();
  }

  // assignToken: next sequential token number
  final maxToken = existingQueue.isEmpty
      ? 0
      : existingQueue.map((e) => e.tokenNo).reduce((a, b) => a > b ? a : b);

  return TokenAssignResult._success(maxToken + 1);
}

/// Returns waiting items sorted by tokenNo ascending — mirrors callNext() in auth_service.dart.
List<QueueItem> fifoOrder(List<QueueItem> queue) {
  final waiting = queue
      .where((item) => item.status == QueueStatus.waiting)
      .toList()
    ..sort((a, b) => a.tokenNo.compareTo(b.tokenNo));
  return waiting;
}

// ── Test helpers ───────────────────────────────────────────────────────────

QueueItem _item(int token, String patientId,
    {QueueStatus status = QueueStatus.waiting}) {
  return QueueItem(
    id: 'id-$token',
    tokenNo: token,
    patientName: 'Patient-$patientId',
    patientId: patientId,
    etaMins: 15,
    status: status,
    timestamp: DateTime.now(),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // UT-04 ──────────────────────────────────────────────────────────────────
  group('UT-04: Queue — assignToken() — empty queue', () {
    test('First patient on an empty queue receives token 1', () {
      final result = assignToken(
        existingQueue: [],
        patientId: 'p-001',
        patientName: 'Alice',
      );

      expect(result.success, isTrue);
      expect(result.tokenNo, equals(1),
          reason: 'First token must be 1 when queue is empty');
    });

    test('Second patient on a one-entry queue receives token 2', () {
      final queue = [_item(1, 'p-001')];

      final result = assignToken(
        existingQueue: queue,
        patientId: 'p-002',
        patientName: 'Bob',
      );

      expect(result.success, isTrue);
      expect(result.tokenNo, equals(2));
    });
  });

  // UT-05 ──────────────────────────────────────────────────────────────────
  group('UT-05: Queue — preventDuplicate()', () {
    test('Patient already waiting: no new token; existing position returned', () {
      final queue = [_item(3, 'p-001')]; // p-001 already at token 3

      final result = assignToken(
        existingQueue: queue,
        patientId: 'p-001',
        patientName: 'Alice',
      );

      expect(result.success, isFalse,
          reason: 'Duplicate tap must not create a new entry');
      expect(result.rejectionReason, equals('duplicate'));
      expect(result.existingTokenNo, equals(3),
          reason: 'Must surface the existing token number');
    });

    test('Patient being served is also treated as a duplicate', () {
      final queue = [_item(1, 'p-001', status: QueueStatus.serving)];

      final result = assignToken(
        existingQueue: queue,
        patientId: 'p-001',
        patientName: 'Alice',
      );

      expect(result.success, isFalse);
      expect(result.rejectionReason, equals('duplicate'));
    });

    test('Patient with status "done" is allowed to re-join', () {
      final queue = [_item(1, 'p-001', status: QueueStatus.done)];

      final result = assignToken(
        existingQueue: queue,
        patientId: 'p-001',
        patientName: 'Alice',
      );

      expect(result.success, isTrue,
          reason: 'A completed visit does not block re-joining');
    });
  });

  // UT-06 ──────────────────────────────────────────────────────────────────
  group('UT-06: Queue — checkDailyLimit() — boundary', () {
    test('Queue exactly at daily limit (20) rejects new patient', () {
      final fullQueue = List.generate(
        kDailyPatientLimit,
        (i) => _item(i + 1, 'patient-$i'),
      );

      final result = assignToken(
        existingQueue: fullQueue,
        patientId: 'new-patient',
        patientName: 'New Patient',
      );

      expect(result.success, isFalse,
          reason: 'Must reject exactly at the limit boundary (count == limit)');
      expect(result.rejectionReason, equals('limit_reached'));
    });

    test('Queue one below limit (19) accepts the new patient', () {
      final almostFullQueue = List.generate(
        kDailyPatientLimit - 1,
        (i) => _item(i + 1, 'patient-$i'),
      );

      final result = assignToken(
        existingQueue: almostFullQueue,
        patientId: 'new-patient',
        patientName: 'New Patient',
      );

      expect(result.success, isTrue,
          reason: 'One slot below limit must still accept');
      expect(result.tokenNo, equals(kDailyPatientLimit),
          reason: 'Token must equal the next sequential number');
    });
  });

  // UT-07 ──────────────────────────────────────────────────────────────────
  group('UT-07: Queue — fifoOrder()', () {
    test('Three tokens added out of order are served in order 1, 2, 3', () {
      // Intentionally insert in non-sequential order
      final queue = [
        _item(3, 'p-003'),
        _item(1, 'p-001'),
        _item(2, 'p-002'),
      ];

      final ordered = fifoOrder(queue);

      expect(
        ordered.map((e) => e.tokenNo).toList(),
        equals([1, 2, 3]),
        reason: 'FIFO order must serve token 1 before 2 before 3',
      );
    });

    test('Items with "done" or "serving" status are excluded from FIFO ordering', () {
      final queue = [
        _item(1, 'p-001', status: QueueStatus.done),
        _item(2, 'p-002', status: QueueStatus.serving),
        _item(3, 'p-003'), // waiting
        _item(4, 'p-004'), // waiting
      ];

      final ordered = fifoOrder(queue);

      expect(ordered.length, equals(2));
      expect(ordered.map((e) => e.tokenNo).toList(), equals([3, 4]));
    });
  });
}
