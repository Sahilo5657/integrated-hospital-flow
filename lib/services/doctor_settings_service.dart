import 'package:cloud_firestore/cloud_firestore.dart';
import 'eta_service.dart';

class DoctorSettings {
  final int dailyLimit;
  final int endTimeHour;
  final int endTimeMinute;

  const DoctorSettings({
    this.dailyLimit = 20,
    this.endTimeHour = 23,
    this.endTimeMinute = 59,
  });

  bool get endTimeSet => endTimeHour < 23 || endTimeMinute < 59;

  String get endTimeLabel =>
      '${endTimeHour.toString().padLeft(2, '0')}:${endTimeMinute.toString().padLeft(2, '0')}';

  factory DoctorSettings.fromMap(Map<String, dynamic> data) => DoctorSettings(
        dailyLimit:    data['dailyLimit']    as int? ?? 20,
        endTimeHour:   data['endTimeHour']   as int? ?? 23,
        endTimeMinute: data['endTimeMinute'] as int? ?? 59,
      );
}

class DoctorSettingsService {
  final String doctorId;
  final FirebaseFirestore _db;

  DoctorSettingsService({required this.doctorId, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<DoctorSettings> getSettings() async {
    try {
      final doc = await _db.collection('doctor_settings').doc(doctorId).get();
      if (!doc.exists || doc.data() == null) return const DoctorSettings();
      return DoctorSettings.fromMap(doc.data()!);
    } catch (_) {
      return const DoctorSettings();
    }
  }

  Future<void> saveSettings(DoctorSettings s) async {
    await _db.collection('doctor_settings').doc(doctorId).set({
      'dailyLimit':    s.dailyLimit,
      'endTimeHour':   s.endTimeHour,
      'endTimeMinute': s.endTimeMinute,
    }, SetOptions(merge: true));
  }

  /// Returns null if patient can join the queue; otherwise returns a
  /// human-readable reason string explaining why they are blocked.
  Future<String?> checkQueueAccess() async {
    final settings = await getSettings();
    final now = DateTime.now();

    final snap = await _db
        .collection('queues')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    int todayCount  = 0;
    int activeCount = 0;
    for (final doc in snap.docs) {
      final ts = doc['timestamp'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          todayCount++;
          final status = doc['status'] as String? ?? '';
          if (status == 'waiting' || status == 'serving') activeCount++;
        }
      }
    }

    if (todayCount >= settings.dailyLimit) {
      return "Doctor has reached today's patient limit "
          "(${settings.dailyLimit} patients). Please try again tomorrow.";
    }

    if (settings.endTimeSet) {
      final endTime = DateTime(now.year, now.month, now.day,
          settings.endTimeHour, settings.endTimeMinute);
      final avgMins =
          await EtaService(firestore: _db).getEstimatedMinutesPerPatient();
      final estimatedStart =
          now.add(Duration(minutes: ((activeCount + 1) * avgMins).round()));
      if (estimatedStart.isAfter(endTime)) {
        return "Doctor's schedule is full for today "
            "(appointments until ${settings.endTimeLabel}). Please come back tomorrow.";
      }
    }

    return null;
  }

  /// Today's count + settings for display widgets (wall, reception).
  Future<({int todayCount, DoctorSettings settings})> getTodayStats() async {
    final settings = await getSettings();
    final now = DateTime.now();

    final snap = await _db
        .collection('queues')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    int todayCount = 0;
    for (final doc in snap.docs) {
      final ts = doc['timestamp'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          todayCount++;
        }
      }
    }
    return (todayCount: todayCount, settings: settings);
  }
}
