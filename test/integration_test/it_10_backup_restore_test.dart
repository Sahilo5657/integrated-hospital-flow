// IT-10: Backup + Restore — Create a backup, then restore it
//
// Integration scope: queue state → createSnapshot (Backup module) →
// data corruption simulation → restore from snapshot → integrity verification.
//
// Verifies that data extracted by the backup step can be faithfully re-injected
// and that the checksum detects any tampering between backup and restore.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Backup/restore logic (mirrors backup_screen.dart) ─────────────────────

class Snapshot {
  final List<Map<String, dynamic>> records;
  final int checksum;
  final DateTime takenAt;

  Snapshot({
    required this.records,
    required this.checksum,
    required this.takenAt,
  });
}

/// Serialises [items] to a snapshot with a simple checksum.
Snapshot createSnapshot(List<QueueItem> items) {
  final records = items.map((item) => {
        'docId': item.id,
        'tokenNo': item.tokenNo,
        'patientName': item.patientName,
        'patientId': item.patientId,
        'status': item.status.name,
        'etaMins': item.etaMins,
        'timestamp': item.timestamp.millisecondsSinceEpoch,
      }).toList();

  final checksum = _computeChecksum(records);
  return Snapshot(records: records, checksum: checksum, takenAt: DateTime.now());
}

int _computeChecksum(List<Map<String, dynamic>> records) {
  final json = jsonEncode(records);
  return json.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
}

/// Returns true if the snapshot's checksum still matches its records.
bool verifyIntegrity(Snapshot snapshot) {
  return _computeChecksum(snapshot.records) == snapshot.checksum;
}

/// Simulates restoring snapshot records back into the live queue.
/// Returns the restored list (mirrors re-writing to Firestore in _runSystemRestore).
List<Map<String, dynamic>> restoreFromSnapshot(Snapshot snapshot) {
  if (!verifyIntegrity(snapshot)) {
    throw StateError('Integrity check failed: snapshot is corrupted');
  }
  // Deep-copy to simulate receiving fresh Firestore documents
  return snapshot.records.map((r) => Map<String, dynamic>.from(r)).toList();
}

// ── Helpers ────────────────────────────────────────────────────────────────

QueueItem _item(int token, String pid, {QueueStatus status = QueueStatus.done}) =>
    QueueItem(
      id: 'doc-$token',
      tokenNo: token,
      patientName: 'Patient-$token',
      patientId: pid,
      etaMins: 15,
      status: status,
      timestamp: DateTime(2026, 6, 19, 9, token),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-10: Backup + Restore — snapshot integrity and data fidelity', () {
    final originalQueue = [
      _item(1, 'p-001'),
      _item(2, 'p-002'),
      _item(3, 'p-003', status: QueueStatus.skipped),
    ];

    late Snapshot snapshot;

    setUp(() {
      snapshot = createSnapshot(originalQueue);
    });

    // ── Backup step ─────────────────────────────────────────────────────

    test('Snapshot contains the correct number of records', () {
      expect(snapshot.records.length, equals(originalQueue.length),
          reason: 'Every queue item must be captured in the snapshot');
    });

    test('Snapshot records carry all required fields', () {
      for (final record in snapshot.records) {
        expect(record.containsKey('docId'), isTrue);
        expect(record.containsKey('tokenNo'), isTrue);
        expect(record.containsKey('patientName'), isTrue);
        expect(record.containsKey('patientId'), isTrue);
        expect(record.containsKey('status'), isTrue);
        expect(record.containsKey('etaMins'), isTrue);
        expect(record.containsKey('timestamp'), isTrue);
      }
    });

    test('Snapshot checksum is non-zero for non-empty data', () {
      expect(snapshot.checksum, isNonZero);
    });

    // ── Integrity check ─────────────────────────────────────────────────

    test('Integrity check passes on an unmodified snapshot', () {
      expect(verifyIntegrity(snapshot), isTrue,
          reason: 'Untampered snapshot must pass integrity verification');
    });

    test('Integrity check fails after snapshot records are tampered', () {
      final tampered = Snapshot(
        records: [
          {...snapshot.records[0], 'patientName': 'TAMPERED'},
          ...snapshot.records.skip(1),
        ],
        checksum: snapshot.checksum, // stale checksum
        takenAt: snapshot.takenAt,
      );

      expect(verifyIntegrity(tampered), isFalse,
          reason: 'Tampered data must fail the checksum check');
    });

    // ── Restore step ────────────────────────────────────────────────────

    test('Restored data matches the pre-backup state', () {
      final restored = restoreFromSnapshot(snapshot);

      expect(restored.length, equals(originalQueue.length),
          reason: 'Restore must return the same number of records');

      for (int i = 0; i < originalQueue.length; i++) {
        expect(restored[i]['tokenNo'], equals(originalQueue[i].tokenNo),
            reason: 'Token numbers must be restored in order');
        expect(restored[i]['patientId'], equals(originalQueue[i].patientId));
        expect(restored[i]['status'], equals(originalQueue[i].status.name));
      }
    });

    test('Restore preserves the original document IDs (docId field)', () {
      final restored = restoreFromSnapshot(snapshot);

      for (int i = 0; i < originalQueue.length; i++) {
        expect(restored[i]['docId'], equals(originalQueue[i].id),
            reason: 'docId must be preserved so Firestore doc identity is maintained');
      }
    });

    test('Restoring a tampered snapshot throws StateError', () {
      final tampered = Snapshot(
        records: [
          {...snapshot.records[0], 'tokenNo': 999},
          ...snapshot.records.skip(1),
        ],
        checksum: snapshot.checksum,
        takenAt: snapshot.takenAt,
      );

      expect(
        () => restoreFromSnapshot(tampered),
        throwsA(isA<StateError>()),
        reason: 'Restore must refuse to apply a snapshot with a bad checksum',
      );
    });

    test('Empty queue produces an empty snapshot that restores to empty', () {
      final emptySnapshot = createSnapshot([]);
      expect(verifyIntegrity(emptySnapshot), isTrue);

      final restored = restoreFromSnapshot(emptySnapshot);
      expect(restored, isEmpty);
    });
  });
}
