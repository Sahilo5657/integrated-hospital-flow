// UT-14: Backup — createSnapshot()
//
// Covers: snapshot creation from sample queue data and checksum integrity.
// Production logic lives in backup_screen.dart (_runSystemBackup / _runSystemRestore).
// This test extracts the snapshot + checksum steps as pure in-memory operations
// that can be verified without Firebase or the file system.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Snapshot helpers ───────────────────────────────────────────────────────

class BackupSnapshot {
  final List<Map<String, dynamic>> records;
  final int checksum;

  BackupSnapshot({required this.records, required this.checksum});
}

/// Serialises [items] to a list of plain maps (mirrors _runSystemBackup).
/// Computes a checksum by summing code-units of the JSON representation so
/// the integrity of the snapshot can be verified before a restore.
BackupSnapshot createSnapshot(List<QueueItem> items) {
  final records = items.map((item) {
    final map = item.toMap();
    // toMap() stores Timestamp; replace with milliseconds for JSON compatibility
    return {
      'docId': item.id,
      'tokenNo': item.tokenNo,
      'patientName': item.patientName,
      'patientId': item.patientId,
      'status': item.status.name,
      'etaMins': item.etaMins,
      'timestamp': item.timestamp.millisecondsSinceEpoch,
    };
  }).toList();

  final json = jsonEncode(records);
  final checksum = json.codeUnits.fold<int>(0, (sum, unit) => sum + unit);

  return BackupSnapshot(records: records, checksum: checksum);
}

/// Verifies that a snapshot's checksum still matches its records.
bool verifyChecksum(BackupSnapshot snapshot) {
  final json = jsonEncode(snapshot.records);
  final recomputed = json.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return recomputed == snapshot.checksum;
}

// ── Test data helper ───────────────────────────────────────────────────────

QueueItem _item(int token, String patientId) => QueueItem(
      id: 'doc-$token',
      tokenNo: token,
      patientName: 'Patient-$token',
      patientId: patientId,
      etaMins: 10,
      status: QueueStatus.done,
      timestamp: DateTime(2026, 6, 19, 9, token),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('UT-14: Backup — createSnapshot()', () {
    test('Snapshot contains the same number of records as the input', () {
      final items = [_item(1, 'p-001'), _item(2, 'p-002'), _item(3, 'p-003')];

      final snapshot = createSnapshot(items);

      expect(snapshot.records.length, equals(items.length),
          reason: 'Every queue item must appear in the snapshot');
    });

    test('Snapshot records contain all required fields', () {
      final snapshot = createSnapshot([_item(1, 'p-001')]);
      final record = snapshot.records.first;

      expect(record.containsKey('docId'), isTrue);
      expect(record.containsKey('tokenNo'), isTrue);
      expect(record.containsKey('patientName'), isTrue);
      expect(record.containsKey('patientId'), isTrue);
      expect(record.containsKey('status'), isTrue);
      expect(record.containsKey('timestamp'), isTrue);
    });

    test('Checksum is non-zero for a non-empty snapshot', () {
      final snapshot = createSnapshot([_item(1, 'p-001')]);

      expect(snapshot.checksum, isNonZero,
          reason: 'A valid snapshot must produce a non-zero checksum');
    });

    test('Snapshot checksum matches when re-computed from the same records', () {
      final items = [_item(1, 'p-001'), _item(2, 'p-002')];

      final snapshot = createSnapshot(items);

      expect(verifyChecksum(snapshot), isTrue,
          reason: 'Checksum must verify correctly against the snapshot data');
    });

    test('Tampered snapshot fails checksum verification', () {
      final items = [_item(1, 'p-001'), _item(2, 'p-002')];
      final snapshot = createSnapshot(items);

      // Simulate tampering — change a field after snapshot is taken
      final tampered = BackupSnapshot(
        records: [
          {...snapshot.records[0], 'patientName': 'TAMPERED'},
          snapshot.records[1],
        ],
        checksum: snapshot.checksum, // original checksum, now stale
      );

      expect(verifyChecksum(tampered), isFalse,
          reason: 'Tampered data must fail checksum verification');
    });

    test('Empty queue produces an empty snapshot with checksum for empty array', () {
      final snapshot = createSnapshot([]);

      expect(snapshot.records, isEmpty);
      // Checksum of "[]" should still be consistent
      expect(verifyChecksum(snapshot), isTrue);
    });
  });
}
