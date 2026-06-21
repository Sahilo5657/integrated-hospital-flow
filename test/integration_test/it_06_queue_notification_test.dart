// IT-06: Queue + Notification — Queue advances so patient is near their turn
//
// Integration scope: queue-advance logic (callNext simulation) → position
// recalculation → notification threshold check → notification trigger.
//
// As the doctor calls each patient, every waiting patient's effective position
// drops. This test verifies that the notification fires exactly when a patient
// crosses the threshold and not before.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Queue advance simulation (mirrors callNext() in auth_service.dart) ─────

/// Advances the queue by one: marks the current 'serving' patient as 'done',
/// then promotes the waiting patient with the lowest tokenNo to 'serving'.
/// Returns the updated queue.
List<QueueItem> advanceQueue(List<QueueItem> queue) {
  final updated = queue.map((item) {
    if (item.status == QueueStatus.serving) {
      return QueueItem(
        id: item.id,
        tokenNo: item.tokenNo,
        patientName: item.patientName,
        patientId: item.patientId,
        etaMins: item.etaMins,
        status: QueueStatus.done,
        timestamp: item.timestamp,
      );
    }
    return item;
  }).toList();

  final waiting = updated
      .where((item) => item.status == QueueStatus.waiting)
      .toList()
    ..sort((a, b) => a.tokenNo.compareTo(b.tokenNo));

  if (waiting.isNotEmpty) {
    final next = waiting.first;
    final idx = updated.indexWhere((item) => item.id == next.id);
    updated[idx] = QueueItem(
      id: next.id,
      tokenNo: next.tokenNo,
      patientName: next.patientName,
      patientId: next.patientId,
      etaMins: next.etaMins,
      status: QueueStatus.serving,
      timestamp: next.timestamp,
    );
  }

  return updated;
}

/// Returns the 1-based position of [patientId] in the active queue.
/// Returns -1 if not found or already done.
int getPosition(List<QueueItem> queue, String patientId) {
  final active = queue
      .where((item) =>
          item.status == QueueStatus.waiting ||
          item.status == QueueStatus.serving)
      .toList()
    ..sort((a, b) => a.tokenNo.compareTo(b.tokenNo));

  final idx = active.indexWhere((item) => item.patientId == patientId);
  return idx == -1 ? -1 : idx + 1;
}

/// Notification threshold rule: notify when position ≤ [threshold].
bool isWithinThreshold(int position, int threshold) => position <= threshold;

// ── Tests ──────────────────────────────────────────────────────────────────

QueueItem _waiting(int token, String pid) => QueueItem(
      id: 'id-$token',
      tokenNo: token,
      patientName: 'P$pid',
      patientId: pid,
      etaMins: 15,
      status: QueueStatus.waiting,
      timestamp: DateTime.now(),
    );

void main() {
  group('IT-06: Queue + Notification — notification triggered as queue advances', () {
    const notifyThreshold = 3;
    const targetPatientId = 'target-patient';

    // Seed: target is 6th in queue (well outside threshold)
    late List<QueueItem> queue;

    setUp(() {
      queue = [
        _waiting(1, 'p1'),
        _waiting(2, 'p2'),
        _waiting(3, 'p3'),
        _waiting(4, 'p4'),
        _waiting(5, 'p5'),
        _waiting(6, targetPatientId), // target starts at position 6
      ];
      // Mark patient 1 as serving (doctor just started)
      queue[0] = QueueItem(
        id: queue[0].id,
        tokenNo: queue[0].tokenNo,
        patientName: queue[0].patientName,
        patientId: queue[0].patientId,
        etaMins: 15,
        status: QueueStatus.serving,
        timestamp: queue[0].timestamp,
      );
    });

    test('Initial position (6) is outside threshold — no notification', () {
      final pos = getPosition(queue, targetPatientId);
      final shouldNotify = isWithinThreshold(pos, notifyThreshold);

      expect(pos, equals(6));
      expect(shouldNotify, isFalse,
          reason: 'Position 6 is outside threshold 3 — must not notify');
    });

    test('After 2 advances (position 4) still outside threshold', () {
      queue = advanceQueue(queue); // p1 done → p2 serving, target at 5
      queue = advanceQueue(queue); // p2 done → p3 serving, target at 4

      final pos = getPosition(queue, targetPatientId);
      expect(pos, equals(4));
      expect(isWithinThreshold(pos, notifyThreshold), isFalse);
    });

    test('After 3 advances (position 3) crosses threshold — notification fires', () {
      queue = advanceQueue(queue);
      queue = advanceQueue(queue);
      queue = advanceQueue(queue); // p3 done → p4 serving, target at 3

      final pos = getPosition(queue, targetPatientId);
      expect(pos, equals(3));
      expect(isWithinThreshold(pos, notifyThreshold), isTrue,
          reason: 'Position 3 == threshold 3 — notification must trigger');
    });

    test('After 5 advances (position 1 — next up) notification is still active', () {
      for (int i = 0; i < 5; i++) {
        queue = advanceQueue(queue);
      }

      final pos = getPosition(queue, targetPatientId);
      expect(pos, equals(1));
      expect(isWithinThreshold(pos, notifyThreshold), isTrue);
    });

    test('Queue state remains consistent after each advance (FIFO order)', () {
      queue = advanceQueue(queue);

      final serving = queue.where((item) => item.status == QueueStatus.serving);
      expect(serving.length, equals(1),
          reason: 'Exactly one patient must be "serving" at a time');

      final done = queue.where((item) => item.status == QueueStatus.done);
      expect(done.length, equals(1),
          reason: 'First patient must be "done" after first advance');
    });
  });
}
