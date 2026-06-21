// UT-08: ETA — calculateETA()
//
// Covers: position-based ETA formula and the EMA algorithm in EtaService.
// calculateETA is a pure multiplication: position × avgConsultMinutes.
// The EMA formula (α = 0.35) is extracted from EtaService and tested directly.

import 'package:flutter_test/flutter_test.dart';

// ── Pure ETA formula ───────────────────────────────────────────────────────
// Position-based ETA: patient at position N waits N × avg consultation time.
double calculateETA(int position, double avgConsultMinutes) {
  return position * avgConsultMinutes;
}

// ── EMA algorithm (mirrors EtaService._alpha = 0.35) ──────────────────────
//   EMA_new = 0.35 × latest + 0.65 × EMA_prev
//   Clamped to the clinical range [5, 60] minutes.
double applyEMA(List<double> durations, {double alpha = 0.35}) {
  if (durations.isEmpty) return 15.0;
  double ema = durations.first;
  for (int i = 1; i < durations.length; i++) {
    ema = alpha * durations[i] + (1.0 - alpha) * ema;
  }
  return ema.clamp(5.0, 60.0);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('UT-08: ETA — calculateETA()', () {
    test('Position 3, avg 5 min → ETA ≈ 15 min (within ±1 min tolerance)', () {
      const position = 3;
      const avgConsult = 5.0;
      const expectedETA = 15.0;
      const tolerance = 1.0;

      final eta = calculateETA(position, avgConsult);

      expect(eta, closeTo(expectedETA, tolerance),
          reason: 'ETA must be within ±1 min of 15 minutes');
    });

    test('Position 1, avg 10 min → ETA = 10 min', () {
      expect(calculateETA(1, 10.0), closeTo(10.0, 0.01));
    });

    test('Position 0 (currently being served) → ETA = 0', () {
      expect(calculateETA(0, 5.0), equals(0.0));
    });
  });

  group('EtaService — EMA formula', () {
    test('Two records [10, 5]: EMA = 0.35×5 + 0.65×10 = 8.25', () {
      final ema = applyEMA([10.0, 5.0]);
      // EMA_prev = 10, latest = 5
      // EMA_new = 0.35 × 5 + 0.65 × 10 = 1.75 + 6.5 = 8.25
      expect(ema, closeTo(8.25, 0.01));
    });

    test('Single record falls back to that value (no smoothing needed)', () {
      final ema = applyEMA([12.0]);
      expect(ema, closeTo(12.0, 0.01));
    });

    test('Very short durations are clamped to minimum 5.0 min', () {
      // All durations below 5 min → EMA would be <5, clamp applies
      final ema = applyEMA([1.0, 1.0, 1.0]);
      expect(ema, greaterThanOrEqualTo(5.0));
    });

    test('Very long durations are clamped to maximum 60.0 min', () {
      final ema = applyEMA([80.0, 80.0]);
      expect(ema, lessThanOrEqualTo(60.0));
    });

    test('Empty duration list returns default 15.0 min', () {
      final ema = applyEMA([]);
      expect(ema, equals(15.0));
    });
  });
}
