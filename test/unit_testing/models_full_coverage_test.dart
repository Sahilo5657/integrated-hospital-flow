// models_full_coverage_test.dart
//
// Drives statement AND branch coverage across all seven model files.
// Each method is exercised with:
//   • complete data  → hits the "field present" branch of every ??
//   • partial/empty data → hits the "field absent / use default" branch
// This ensures both paths of every null-coalescing operator are covered.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/doctor_model.dart';
import 'package:hospital_flow_app/models/encounter_model.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';
import 'package:hospital_flow_app/models/patient_model.dart';
import 'package:hospital_flow_app/models/queue_models.dart';
import 'package:hospital_flow_app/models/summary_model.dart';
import 'package:hospital_flow_app/models/user_profile.dart';

// ── Shared fixtures ────────────────────────────────────────────────────────

final _ts = Timestamp.fromDate(DateTime(2026, 6, 19, 10, 0));
final _dt = DateTime(2026, 6, 19, 10, 0);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // UserProfile
  // ════════════════════════════════════════════════════════════════════════
  group('UserProfile', () {
    test('constructor stores all fields', () {
      final p = UserProfile(uid: 'u1', email: 'e@h.com', role: 'doctor', name: 'Dr A');
      expect(p.uid, 'u1');
      expect(p.email, 'e@h.com');
      expect(p.role, 'doctor');
      expect(p.name, 'Dr A');
    });

    test('fromFirestore — all fields present', () {
      final p = UserProfile.fromFirestore(
        {'email': 'e@h.com', 'role': 'patient', 'name': 'Jane'},
        'uid-1',
      );
      expect(p.uid, 'uid-1');
      expect(p.role, 'patient');
      expect(p.name, 'Jane');
    });

    test('fromFirestore — missing role defaults to "patient" (branch: null path)', () {
      final p = UserProfile.fromFirestore({'email': 'x@y.com', 'name': 'X'}, 'uid-2');
      expect(p.role, 'patient');
    });

    test('fromFirestore — missing name defaults to empty string', () {
      final p = UserProfile.fromFirestore({'email': 'x@y.com', 'role': 'staff'}, 'uid-3');
      expect(p.name, '');
    });

    test('fromFirestore — missing email defaults to empty string', () {
      final p = UserProfile.fromFirestore({'role': 'doctor', 'name': 'Doc'}, 'uid-4');
      expect(p.email, '');
    });

    test('toMap() serialises all fields', () {
      final p = UserProfile(uid: 'u1', email: 'e@h.com', role: 'doctor', name: 'Dr A');
      final m = p.toMap();
      expect(m['email'], 'e@h.com');
      expect(m['role'], 'doctor');
      expect(m['name'], 'Dr A');
      expect(m.containsKey('uid'), isFalse); // uid is doc id, not in map
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // NFCCardModel
  // ════════════════════════════════════════════════════════════════════════
  group('NFCCardModel', () {
    test('constructor defaults isActive to true', () {
      final c = NFCCardModel(cardId: 'C1');
      expect(c.isActive, isTrue);
      expect(c.assignedPatientId, isNull);
    });

    test('constructor with all fields', () {
      final c = NFCCardModel(cardId: 'C2', assignedPatientId: 'p1', isActive: false);
      expect(c.isActive, isFalse);
      expect(c.assignedPatientId, 'p1');
    });

    test('fromFirestore — active card with patient', () {
      final c = NFCCardModel.fromFirestore(
        {'isActive': true, 'assignedPatientId': 'uid-patient'},
        'CARD-1',
      );
      expect(c.cardId, 'CARD-1');
      expect(c.isActive, isTrue);
      expect(c.assignedPatientId, 'uid-patient');
    });

    test('fromFirestore — inactive card, missing patientId', () {
      final c = NFCCardModel.fromFirestore({'isActive': false}, 'CARD-2');
      expect(c.isActive, isFalse);
      expect(c.assignedPatientId, isNull);
    });

    test('fromFirestore — missing isActive defaults to true (branch: null path)', () {
      final c = NFCCardModel.fromFirestore({}, 'CARD-3');
      expect(c.isActive, isTrue);
    });

    test('toMap() serialises correctly', () {
      final c = NFCCardModel(cardId: 'C1', assignedPatientId: 'p1', isActive: true);
      final m = c.toMap();
      expect(m['assignedPatientId'], 'p1');
      expect(m['isActive'], isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TapLogModel
  // ════════════════════════════════════════════════════════════════════════
  group('TapLogModel', () {
    test('constructor stores all fields', () {
      final t = TapLogModel(
        logId: 'log-1',
        cardId: 'CARD-1',
        patientId: 'pid-1',
        readerDeviceId: 'reader-A',
        timestamp: _dt,
      );
      expect(t.logId, 'log-1');
      expect(t.cardId, 'CARD-1');
      expect(t.patientId, 'pid-1');
    });

    test('constructor — optional fields are nullable', () {
      final t = TapLogModel(
        cardId: 'CARD-X',
        readerDeviceId: 'reader-B',
        timestamp: _dt,
      );
      expect(t.logId, isNull);
      expect(t.patientId, isNull);
    });

    test('fromFirestore — all fields present', () {
      final t = TapLogModel.fromFirestore(
        {
          'cardId': 'CARD-1',
          'patientId': 'pid-1',
          'readerDeviceId': 'reader-A',
          'timestamp': _ts,
        },
        'log-1',
      );
      expect(t.logId, 'log-1');
      expect(t.cardId, 'CARD-1');
      expect(t.patientId, 'pid-1');
      expect(t.readerDeviceId, 'reader-A');
      expect(t.timestamp, _dt);
    });

    test('fromFirestore — missing cardId defaults to empty string (branch: null path)', () {
      final t = TapLogModel.fromFirestore(
        {'readerDeviceId': 'r1', 'timestamp': _ts},
        'log-2',
      );
      expect(t.cardId, '');
    });

    test('fromFirestore — missing readerDeviceId defaults to "unknown"', () {
      final t = TapLogModel.fromFirestore(
        {'cardId': 'C1', 'timestamp': _ts},
        'log-3',
      );
      expect(t.readerDeviceId, 'unknown');
    });

    test('toMap() serialises Timestamp correctly', () {
      final t = TapLogModel(
        cardId: 'CARD-1',
        patientId: 'pid-1',
        readerDeviceId: 'reader-A',
        timestamp: _dt,
      );
      final m = t.toMap();
      expect(m['cardId'], 'CARD-1');
      expect(m['patientId'], 'pid-1');
      expect(m['readerDeviceId'], 'reader-A');
      expect(m['timestamp'], isA<Timestamp>());
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // QueueItem + QueueStatus + QueueStatusX
  // ════════════════════════════════════════════════════════════════════════
  group('QueueStatus + QueueStatusX.label', () {
    test('label capitalises each status name', () {
      expect(QueueStatus.waiting.label, 'Waiting');
      expect(QueueStatus.serving.label, 'Serving');
      expect(QueueStatus.done.label, 'Done');
      expect(QueueStatus.skipped.label, 'Skipped');
    });
  });

  group('QueueItem', () {
    test('constructor stores all fields with default status=waiting', () {
      final q = QueueItem(
        id: 'q1', tokenNo: 3, patientName: 'Ali', patientId: 'p1',
        etaMins: 15, timestamp: _dt,
      );
      expect(q.status, QueueStatus.waiting);
      expect(q.tokenNo, 3);
    });

    test('toMap() serialises status as string and timestamp as Timestamp', () {
      final q = QueueItem(
        id: 'q1', tokenNo: 1, patientName: 'Ali', patientId: 'p1',
        etaMins: 10, status: QueueStatus.done, timestamp: _dt,
      );
      final m = q.toMap();
      expect(m['status'], 'done');
      expect(m['tokenNo'], 1);
      expect(m['timestamp'], isA<Timestamp>());
    });

    test('fromMap() — complete data (all ?? branches: non-null path)', () {
      final q = QueueItem.fromMap({
        'tokenNo': 5,
        'patientName': 'Sara',
        'patientId': 'p-5',
        'etaMins': 20,
        'status': 'serving',
        'timestamp': _ts,
      }, 'doc-5');

      expect(q.id, 'doc-5');
      expect(q.tokenNo, 5);
      expect(q.patientName, 'Sara');
      expect(q.patientId, 'p-5');
      expect(q.etaMins, 20);
      expect(q.status, QueueStatus.serving);
      expect(q.timestamp, _dt);
    });

    test('fromMap() — missing fields use defaults (?? null path)', () {
      final q = QueueItem.fromMap({}, 'doc-empty');

      expect(q.tokenNo, 0);
      expect(q.patientName, 'Unknown');
      expect(q.patientId, 'N/A');
      expect(q.etaMins, 0);
      expect(q.status, QueueStatus.waiting);
    });

    test('fromMap() — null timestamp uses DateTime.now() (branch: null path)', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final q = QueueItem.fromMap({'tokenNo': 1}, 'doc-no-ts');
      expect(q.timestamp.isAfter(before), isTrue);
    });

    test('fromMap() — unknown status string falls back to waiting (orElse branch)', () {
      final q = QueueItem.fromMap({'status': 'unknown_status'}, 'doc-bad-status');
      expect(q.status, QueueStatus.waiting);
    });

    test('fromMap() — all four status values parse correctly', () {
      for (final s in QueueStatus.values) {
        final q = QueueItem.fromMap({'status': s.name}, 'doc-${s.name}');
        expect(q.status, s);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // EncounterModel
  // ════════════════════════════════════════════════════════════════════════
  group('EncounterModel', () {
    test('constructor stores all fields', () {
      final e = EncounterModel(
        id: 'enc-1', patientId: 'p1', doctorId: 'd1',
        clinicalNotes: 'notes', timestamp: _dt,
      );
      expect(e.id, 'enc-1');
      expect(e.clinicalNotes, 'notes');
    });

    test('toMap() serialises timestamp as Timestamp', () {
      final e = EncounterModel(
        id: 'enc-1', patientId: 'p1', doctorId: 'd1',
        clinicalNotes: 'notes', timestamp: _dt,
      );
      final m = e.toMap();
      expect(m['patientId'], 'p1');
      expect(m['doctorId'], 'd1');
      expect(m['clinicalNotes'], 'notes');
      expect(m['timestamp'], isA<Timestamp>());
    });

    test('fromMap() — complete data (non-null branches)', () {
      final e = EncounterModel.fromMap({
        'patientId': 'p1',
        'doctorId': 'd1',
        'clinicalNotes': 'Patient has fever.',
        'timestamp': _ts,
      }, 'enc-1');

      expect(e.id, 'enc-1');
      expect(e.patientId, 'p1');
      expect(e.doctorId, 'd1');
      expect(e.clinicalNotes, 'Patient has fever.');
      expect(e.timestamp, _dt);
    });

    test('fromMap() — missing fields default to empty string (null branches)', () {
      final e = EncounterModel.fromMap({'timestamp': _ts}, 'enc-empty');
      expect(e.patientId, '');
      expect(e.doctorId, '');
      expect(e.clinicalNotes, '');
    });

    test('toMap() and fromMap() round-trip preserves data', () {
      final original = EncounterModel(
        id: 'enc-rt', patientId: 'p1', doctorId: 'd1',
        clinicalNotes: 'Diagnosis: flu.', timestamp: _dt,
      );
      final map = original.toMap();
      final restored = EncounterModel.fromMap(map, original.id);
      expect(restored.patientId, original.patientId);
      expect(restored.doctorId, original.doctorId);
      expect(restored.clinicalNotes, original.clinicalNotes);
      expect(restored.timestamp, original.timestamp);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // PatientModel
  // ════════════════════════════════════════════════════════════════════════
  group('PatientModel', () {
    test('constructor stores all fields', () {
      final p = PatientModel(
        uid: 'u1', name: 'Ali', contact: '+601', nfcCardId: 'C1', createdAt: _dt,
      );
      expect(p.uid, 'u1');
      expect(p.nfcCardId, 'C1');
    });

    test('toMap() serialises createdAt as Timestamp', () {
      final p = PatientModel(uid: 'u1', name: 'Ali', contact: '+60', createdAt: _dt);
      final m = p.toMap();
      expect(m['name'], 'Ali');
      expect(m['contact'], '+60');
      expect(m['nfcCardId'], isNull);
      expect(m['createdAt'], isA<Timestamp>());
    });

    test('fromMap() — complete data (non-null branches)', () {
      final p = PatientModel.fromMap({
        'name': 'Sara',
        'contact': '+601234',
        'nfcCardId': 'CARD-A',
        'createdAt': _ts,
      }, 'uid-sara');

      expect(p.uid, 'uid-sara');
      expect(p.name, 'Sara');
      expect(p.contact, '+601234');
      expect(p.nfcCardId, 'CARD-A');
    });

    test('fromMap() — missing name defaults to empty string (null branch)', () {
      final p = PatientModel.fromMap({'contact': '+60', 'createdAt': _ts}, 'uid-x');
      expect(p.name, '');
    });

    test('fromMap() — missing contact defaults to empty string (null branch)', () {
      final p = PatientModel.fromMap({'name': 'X', 'createdAt': _ts}, 'uid-y');
      expect(p.contact, '');
    });

    test('fromMap() — missing nfcCardId stays null', () {
      final p = PatientModel.fromMap({'name': 'X', 'contact': '+60', 'createdAt': _ts}, 'uid-z');
      expect(p.nfcCardId, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // SummaryModel
  // ════════════════════════════════════════════════════════════════════════
  group('SummaryModel', () {
    test('constructor stores all fields', () {
      final s = SummaryModel(
        id: 's1',
        encounterId: 'enc-1',
        summaryText: 'Patient has hypertension.',
        timestamp: _dt,
      );
      expect(s.id, 's1');
      expect(s.encounterId, 'enc-1');
      expect(s.summaryText, 'Patient has hypertension.');
    });

    test('toMap() serialises encounterId, summaryText, and Timestamp', () {
      final s = SummaryModel(
        id: 's1', encounterId: 'enc-1', summaryText: 'Summary text.', timestamp: _dt,
      );
      final m = s.toMap();
      expect(m['encounterId'], 'enc-1');
      expect(m['summaryText'], 'Summary text.');
      expect(m['timestamp'], isA<Timestamp>());
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // DoctorModel
  // ════════════════════════════════════════════════════════════════════════
  group('DoctorModel', () {
    test('constructor stores all fields', () {
      final d = DoctorModel(
        uid: 'd1', name: 'Dr Ali', specialization: 'GP',
        clinicRoom: 'Room 1', dailyLimit: 30,
      );
      expect(d.uid, 'd1');
      expect(d.dailyLimit, 30);
    });

    test('toMap() serialises all fields except uid', () {
      final d = DoctorModel(
        uid: 'd1', name: 'Dr Ali', specialization: 'GP',
        clinicRoom: 'Room 1', dailyLimit: 25,
      );
      final m = d.toMap();
      expect(m['name'], 'Dr Ali');
      expect(m['specialization'], 'GP');
      expect(m['clinicRoom'], 'Room 1');
      expect(m['dailyLimit'], 25);
    });

    test('fromMap() — complete data (non-null branches)', () {
      final d = DoctorModel.fromMap({
        'name': 'Dr B',
        'specialization': 'Cardiology',
        'clinicRoom': 'Room 3',
        'dailyLimit': 15,
      }, 'doc-uid');

      expect(d.uid, 'doc-uid');
      expect(d.name, 'Dr B');
      expect(d.specialization, 'Cardiology');
      expect(d.clinicRoom, 'Room 3');
      expect(d.dailyLimit, 15);
    });

    test('fromMap() — missing name defaults to empty string (null branch)', () {
      final d = DoctorModel.fromMap({
        'specialization': 'GP', 'clinicRoom': 'R1', 'dailyLimit': 20,
      }, 'uid-x');
      expect(d.name, '');
    });

    test('fromMap() — missing specialization defaults to empty string (null branch)', () {
      final d = DoctorModel.fromMap({'name': 'Dr X', 'clinicRoom': 'R1', 'dailyLimit': 20}, 'uid-y');
      expect(d.specialization, '');
    });

    test('fromMap() — missing clinicRoom defaults to empty string (null branch)', () {
      final d = DoctorModel.fromMap({'name': 'Dr X', 'specialization': 'GP', 'dailyLimit': 20}, 'uid-z');
      expect(d.clinicRoom, '');
    });

    test('fromMap() — missing dailyLimit defaults to 20 (null branch)', () {
      final d = DoctorModel.fromMap({'name': 'Dr X', 'specialization': 'GP', 'clinicRoom': 'R1'}, 'uid-w');
      expect(d.dailyLimit, 20);
    });

    test('toMap() and fromMap() round-trip preserves data', () {
      final original = DoctorModel(
        uid: 'd-rt', name: 'Dr RT', specialization: 'ENT', clinicRoom: 'Room 5', dailyLimit: 18,
      );
      final restored = DoctorModel.fromMap(original.toMap(), original.uid);
      expect(restored.name, original.name);
      expect(restored.specialization, original.specialization);
      expect(restored.clinicRoom, original.clinicRoom);
      expect(restored.dailyLimit, original.dailyLimit);
    });
  });
}
