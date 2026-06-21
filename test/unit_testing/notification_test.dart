// UT-09: Notification — isWithinThreshold()
//
// The app does not yet have a dedicated notification service; notifications
// are planned to fire when a patient's queue position falls within a threshold.
// This test verifies the threshold predicate used to decide whether to notify.

import 'package:flutter_test/flutter_test.dart';

// Threshold rule: notify when the patient's position is ≤ notifyThreshold.
// Position is 1-based (1 = next to be called, 0 = currently being served).
bool isWithinThreshold(int currentPosition, int notifyThreshold) {
  return currentPosition <= notifyThreshold;
}

void main() {
  group('UT-09: Notification — isWithinThreshold()', () {
    const threshold = 3; // notify when 3 or fewer patients remain ahead

    test('Position within threshold returns true (should notify)', () {
      expect(isWithinThreshold(1, threshold), isTrue,
          reason: 'Position 1 is well within threshold 3');
      expect(isWithinThreshold(2, threshold), isTrue);
    });

    test('Position exactly at threshold returns true (boundary inclusive)', () {
      expect(isWithinThreshold(threshold, threshold), isTrue,
          reason: 'Position exactly equal to threshold must still notify');
    });

    test('Position outside threshold returns false (do not notify)', () {
      expect(isWithinThreshold(4, threshold), isFalse,
          reason: 'Position 4 exceeds threshold 3 — no notification');
      expect(isWithinThreshold(10, threshold), isFalse);
    });

    test('Position 0 (currently being served) always returns true', () {
      expect(isWithinThreshold(0, threshold), isTrue,
          reason: 'A patient currently being served must always be notified');
    });

    test('Different threshold values work correctly', () {
      expect(isWithinThreshold(5, 5), isTrue);
      expect(isWithinThreshold(6, 5), isFalse);
      expect(isWithinThreshold(1, 1), isTrue);
      expect(isWithinThreshold(2, 1), isFalse);
    });
  });
}
