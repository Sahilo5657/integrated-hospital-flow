import 'package:cloud_firestore/cloud_firestore.dart';

/// Estimates average consultation duration (in minutes) using
/// **Exponential Moving Average (EMA)** applied to inter-encounter timestamps.
///
/// Technology: Single Exponential Smoothing from time-series analysis /
/// queue theory (M/G/1 queue model). Each new data point is weighted at
/// α = 0.35 against the running average, so the estimate adapts to today's
/// pace within 2–3 patients while still anchoring to history.
///
///   EMA_new = 0.35 × latest_duration + 0.65 × EMA_prev
///
/// The same approach is used in financial analysis, network latency
/// estimation, and hospital patient-flow planning systems.
class EtaService {
  static const double _default = 15.0;
  static const double _alpha = 0.35;
  static const String _doctorId = 'sahilo5657@gmail.com';

  /// Returns the estimated minutes per consultation.
  /// Falls back to 15 min when fewer than 2 historical records exist.
  Future<double> getEstimatedMinutesPerPatient() async {
    try {
      // Single where clause — avoids composite Firestore index.
      final snapshot = await FirebaseFirestore.instance
          .collection('encounters')
          .where('doctorId', isEqualTo: _doctorId)
          .get();

      if (snapshot.docs.length < 2) return _default;

      // Sort in memory by timestamp (ascending)
      final sorted = snapshot.docs
          .where((d) => d['timestamp'] != null)
          .toList()
        ..sort((a, b) {
          final ta = (a['timestamp'] as Timestamp).millisecondsSinceEpoch;
          final tb = (b['timestamp'] as Timestamp).millisecondsSinceEpoch;
          return ta.compareTo(tb);
        });

      if (sorted.length < 2) return _default;

      // Derive consultation durations from gaps between consecutive completions
      final durations = <double>[];
      for (int i = 1; i < sorted.length; i++) {
        final prev = (sorted[i - 1]['timestamp'] as Timestamp).toDate();
        final curr = (sorted[i]['timestamp'] as Timestamp).toDate();
        final diffMins = curr.difference(prev).inMinutes.toDouble();
        // Sanity window: ignore same-second saves and gaps over 90 min
        if (diffMins >= 1.0 && diffMins <= 90.0) {
          durations.add(diffMins);
        }
      }

      if (durations.isEmpty) return _default;

      // Apply EMA: older values give the baseline, newer values refine it
      double ema = durations.first;
      for (int i = 1; i < durations.length; i++) {
        ema = _alpha * durations[i] + (1.0 - _alpha) * ema;
      }

      // Clamp to a sensible clinical range (5 – 60 min)
      return ema.clamp(5.0, 60.0);
    } catch (_) {
      return _default;
    }
  }
}
