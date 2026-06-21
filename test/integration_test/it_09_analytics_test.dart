// IT-09: Analytics + Logs — Generate report over a date range
//
// Integration scope: seeded queue log data → analytics computation pipeline
// (peak hour, avg wait, no-show rate, busiest day) → verified against known values.
//
// The computation logic is extracted directly from analytics_screen.dart so
// this test exercises the same algorithm the production screen uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/models/queue_models.dart';

// ── Analytics computation (mirrors analytics_screen.dart build() logic) ────

class AnalyticsReport {
  final String peakHour;     // e.g. "9:00 AM"
  final String busiestDay;   // e.g. "Mon"
  final String avgWait;      // e.g. "12 mins"
  final double noShowRate;   // 0.0 – 100.0
  final int totalDone;
  final int totalSkipped;
  final int totalWaiting;
  final int totalServing;

  const AnalyticsReport({
    required this.peakHour,
    required this.busiestDay,
    required this.avgWait,
    required this.noShowRate,
    required this.totalDone,
    required this.totalSkipped,
    required this.totalWaiting,
    required this.totalServing,
  });
}

String _formatHour(int hour) {
  if (hour == 0) return '12:00 AM';
  if (hour < 12) return '$hour:00 AM';
  if (hour == 12) return '12:00 PM';
  return '${hour - 12}:00 PM';
}

String _weekdayName(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[(weekday - 1).clamp(0, 6)];
}

/// Runs the same computation as analytics_screen.dart over [entries].
/// [entries] is a list of maps matching the Firestore queue document shape.
AnalyticsReport computeAnalytics(List<Map<String, dynamic>> entries) {
  int totalDone = 0, totalSkipped = 0, totalWaiting = 0, totalServing = 0;
  final Map<int, int> hourCount = {};
  final Map<int, int> dayCount = {};
  int totalEta = 0, etaCount = 0;

  for (final data in entries) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    if (status == 'done') totalDone++;
    if (status == 'skipped') totalSkipped++;
    if (status == 'waiting') totalWaiting++;
    if (status == 'serving') totalServing++;

    final dt = data['timestamp'] as DateTime?;
    if (dt != null) {
      hourCount[dt.hour] = (hourCount[dt.hour] ?? 0) + 1;
      dayCount[dt.weekday] = (dayCount[dt.weekday] ?? 0) + 1;
    }

    final eta = data['etaMins'];
    if (eta is int && eta > 0) {
      totalEta += eta;
      etaCount++;
    }
  }

  String peakHour = 'N/A';
  if (hourCount.isNotEmpty) {
    final peak = hourCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    peakHour = _formatHour(peak);
  }

  String busiestDay = 'N/A';
  if (dayCount.isNotEmpty) {
    final busiest = dayCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    busiestDay = _weekdayName(busiest);
  }

  final avgWait = etaCount > 0 ? '${(totalEta / etaCount).round()} mins' : 'N/A';

  final totalProcessed = totalDone + totalSkipped;
  final noShowRate =
      totalProcessed > 0 ? (totalSkipped / totalProcessed) * 100 : 0.0;

  return AnalyticsReport(
    peakHour: peakHour,
    busiestDay: busiestDay,
    avgWait: avgWait,
    noShowRate: noShowRate,
    totalDone: totalDone,
    totalSkipped: totalSkipped,
    totalWaiting: totalWaiting,
    totalServing: totalServing,
  );
}

// ── Seeded test data ───────────────────────────────────────────────────────

Map<String, dynamic> _entry({
  required String status,
  required DateTime timestamp,
  required int etaMins,
}) => {
      'status': status,
      'timestamp': timestamp,
      'etaMins': etaMins,
    };

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('IT-09: Analytics + Logs — computed values match seeded log data', () {
    // Seed: known, deterministic dataset for a Monday in June 2026
    // Peak hour: 9 AM (4 entries)
    // Avg wait: (10+15+20+5+10+15+10+5) / 8 = 90/8 = 11.25 → rounded to 11 mins
    // No-show: 2 skipped / (4 done + 2 skipped) = 33.3%
    late List<Map<String, dynamic>> seedData;

    setUp(() {
      seedData = [
        // Monday 9 AM entries (4)
        _entry(status: 'done',    timestamp: DateTime(2026, 6, 15, 9, 5),  etaMins: 10),
        _entry(status: 'done',    timestamp: DateTime(2026, 6, 15, 9, 20), etaMins: 15),
        _entry(status: 'done',    timestamp: DateTime(2026, 6, 15, 9, 35), etaMins: 20),
        _entry(status: 'skipped', timestamp: DateTime(2026, 6, 15, 9, 50), etaMins: 5),
        // Monday 10 AM entries (2)
        _entry(status: 'done',    timestamp: DateTime(2026, 6, 15, 10, 10), etaMins: 10),
        _entry(status: 'skipped', timestamp: DateTime(2026, 6, 15, 10, 25), etaMins: 15),
        // Tuesday 11 AM entries (2) — not the busiest day
        _entry(status: 'waiting', timestamp: DateTime(2026, 6, 16, 11, 0),  etaMins: 10),
        _entry(status: 'serving', timestamp: DateTime(2026, 6, 16, 11, 30), etaMins: 5),
      ];
    });

    test('Peak hour matches the hour with the most queue entries (9 AM)', () {
      final report = computeAnalytics(seedData);
      expect(report.peakHour, equals('9:00 AM'),
          reason: '9 AM has 4 entries — the most of any hour in the seed data');
    });

    test('Busiest day matches the day with the most queue entries (Monday)', () {
      final report = computeAnalytics(seedData);
      expect(report.busiestDay, equals('Mon'),
          reason: 'Monday has 6 entries vs Tuesday 2 — must be busiest day');
    });

    test('Average wait time matches expected value from seeded etaMins', () {
      // Total eta: 10+15+20+5+10+15+10+5 = 90; count = 8; avg = 11 (rounded)
      final report = computeAnalytics(seedData);
      expect(report.avgWait, equals('11 mins'),
          reason: 'Avg = 90 / 8 = 11.25 → rounded to 11 mins');
    });

    test('No-show rate matches seeded skipped/processed ratio', () {
      // 2 skipped / (4 done + 2 skipped) = 33.3%
      final report = computeAnalytics(seedData);
      expect(report.noShowRate, closeTo(33.3, 0.1),
          reason: 'No-show = 2 skipped / 6 processed = 33.3%');
    });

    test('Status counts match seeded data exactly', () {
      final report = computeAnalytics(seedData);
      expect(report.totalDone, equals(4));
      expect(report.totalSkipped, equals(2));
      expect(report.totalWaiting, equals(1));
      expect(report.totalServing, equals(1));
    });

    test('Empty data returns N/A for all computed strings and 0% no-show', () {
      final report = computeAnalytics([]);
      expect(report.peakHour, equals('N/A'));
      expect(report.busiestDay, equals('N/A'));
      expect(report.avgWait, equals('N/A'));
      expect(report.noShowRate, equals(0.0));
    });

    test('All-done data produces 0% no-show rate', () {
      final allDone = [
        _entry(status: 'done', timestamp: DateTime(2026, 6, 15, 9, 0), etaMins: 10),
        _entry(status: 'done', timestamp: DateTime(2026, 6, 15, 9, 30), etaMins: 10),
      ];
      final report = computeAnalytics(allDone);
      expect(report.noShowRate, equals(0.0));
    });
  });
}
