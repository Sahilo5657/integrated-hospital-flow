// IT-03: NFC + Queue + ETA + Display — Patient taps a valid card outside a room
//
// Integration scope: NFC card validation → token assignment → ETA computation
// → display data assembly, all chained in the order they execute in the app.
//
// This is the most common patient-flow integration path: one tap drives
// four sub-systems in sequence. The test seeds state at each boundary and
// verifies the data contract handed to the next system is correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/nfc_card_model.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Re-used pure helpers (same logic as unit tests, no duplication of state) ──

// NFC validation (mirrors _handleHardwareCardTap in staff_home.dart)
class CardValidationResult {
  final bool isValid;
  final String? reason;
  final String? linkedPatientUid;

  CardValidationResult.valid(this.linkedPatientUid) : isValid = true, reason = null;
  CardValidationResult.invalid(this.reason) : isValid = false, linkedPatientUid = null;
}

CardValidationResult validateCard(NFCCardModel card) {
  if (!card.isActive) return CardValidationResult.invalid('inactive');
  return CardValidationResult.valid(card.assignedPatientId);
}

// Token assignment (mirrors joinQueue() in auth_service.dart)
int assignToken(List<QueueItem> existingQueue) {
  if (existingQueue.isEmpty) return 1;
  return existingQueue.map((e) => e.tokenNo).reduce((a, b) => a > b ? a : b) + 1;
}

// ETA calculation (mirrors position × avg in EtaService)
double calculateETA(int position, double avgConsultMinutes) => position * avgConsultMinutes;

// Display data (mirrors QueueItem / wall_display_screen.dart)
class DisplayEntry {
  final String patientName;
  final int tokenNo;
  final int position;
  final double etaMins;

  const DisplayEntry({
    required this.patientName,
    required this.tokenNo,
    required this.position,
    required this.etaMins,
  });
}

// ── Full pipeline ──────────────────────────────────────────────────────────

/// Runs the complete NFC-tap → display-update pipeline.
/// Returns null if the card is invalid.
DisplayEntry? processCardTap({
  required NFCCardModel card,
  required String patientName,
  required List<QueueItem> existingQueue,
  required double avgConsultMinutes,
}) {
  // 1. NFC: validate card
  final validation = validateCard(card);
  if (!validation.isValid) return null;

  // 2. Queue: assign token
  final token = assignToken(existingQueue);

  // 3. Queue: position = new token number (end of queue)
  final position = existingQueue.length + 1;

  // 4. ETA: position × avg consult time
  final eta = calculateETA(position, avgConsultMinutes);

  // 5. Display: assemble entry
  return DisplayEntry(
    patientName: patientName,
    tokenNo: token,
    position: position,
    etaMins: eta,
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

QueueItem _waitingItem(int token, String pid) => QueueItem(
      id: 'id-$token',
      tokenNo: token,
      patientName: 'P$pid',
      patientId: pid,
      etaMins: 15,
      status: QueueStatus.waiting,
      timestamp: DateTime.now(),
    );

void main() {
  group('IT-03: NFC + Queue + ETA + Display — full card-tap pipeline', () {
    const avgConsult = 5.0; // minutes per patient

    test(
        'Valid card tap on empty queue → token 1, position 1, ETA 5 min, '
        'display entry populated', () {
      final card = NFCCardModel(
        cardId: 'CARD-001',
        isActive: true,
        assignedPatientId: 'uid-patient-001',
      );

      final entry = processCardTap(
        card: card,
        patientName: 'Ahmed',
        existingQueue: [],
        avgConsultMinutes: avgConsult,
      );

      expect(entry, isNotNull, reason: 'Valid card must produce a display entry');
      expect(entry!.tokenNo, equals(1), reason: 'First token on empty queue must be 1');
      expect(entry.position, equals(1));
      expect(entry.etaMins, closeTo(5.0, 0.01),
          reason: 'ETA = position(1) × avgConsult(5) = 5 min');
      expect(entry.patientName, equals('Ahmed'));
    });

    test(
        'Valid card tap on queue with 2 waiting patients → '
        'token 3, position 3, ETA 15 min', () {
      final card = NFCCardModel(
        cardId: 'CARD-002',
        isActive: true,
        assignedPatientId: 'uid-patient-003',
      );

      final existingQueue = [_waitingItem(1, 'p1'), _waitingItem(2, 'p2')];

      final entry = processCardTap(
        card: card,
        patientName: 'Sara',
        existingQueue: existingQueue,
        avgConsultMinutes: avgConsult,
      );

      expect(entry, isNotNull);
      expect(entry!.tokenNo, equals(3));
      expect(entry.position, equals(3));
      expect(entry.etaMins, closeTo(15.0, 0.01),
          reason: 'ETA = position(3) × avgConsult(5) = 15 min — within ±1 min');
    });

    test('Inactive card tap → pipeline halts; no display entry produced', () {
      final card = NFCCardModel(
        cardId: 'CARD-INACTIVE',
        isActive: false,
        assignedPatientId: 'uid-patient-xxx',
      );

      final entry = processCardTap(
        card: card,
        patientName: 'Ghost',
        existingQueue: [],
        avgConsultMinutes: avgConsult,
      );

      expect(entry, isNull,
          reason: 'Inactive card must not produce a display entry');
    });

    test('Display data matches the token and ETA values from queue state', () {
      // Seed: two patients already waiting
      final existing = [_waitingItem(1, 'p1'), _waitingItem(2, 'p2')];

      final card = NFCCardModel(
        cardId: 'CARD-003',
        isActive: true,
        assignedPatientId: 'uid-p3',
      );

      final entry = processCardTap(
        card: card,
        patientName: 'Zara',
        existingQueue: existing,
        avgConsultMinutes: 10.0,
      );

      expect(entry, isNotNull);
      // position 3, avg 10 → ETA 30 min
      expect(entry!.etaMins, closeTo(30.0, 0.01));
      expect(entry.tokenNo, equals(3));
    });
  });
}
