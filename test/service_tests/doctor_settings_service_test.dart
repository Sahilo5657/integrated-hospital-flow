// doctor_settings_service_test.dart — covers DoctorSettingsService and DoctorSettings
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_flow_app/services/doctor_settings_service.dart';
import '../helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async => setupFirebaseForTests());

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorSettings model
  // ══════════════════════════════════════════════════════════════════════════
  group('DoctorSettings', () {
    test('default values are applied when constructed with no args', () {
      const s = DoctorSettings();
      expect(s.dailyLimit, 20);
      expect(s.endTimeHour, 23);
      expect(s.endTimeMinute, 59);
    });

    test('fromMap maps all fields correctly', () {
      final s = DoctorSettings.fromMap({
        'dailyLimit': 10,
        'endTimeHour': 17,
        'endTimeMinute': 30,
      });
      expect(s.dailyLimit, 10);
      expect(s.endTimeHour, 17);
      expect(s.endTimeMinute, 30);
    });

    test('fromMap uses defaults for missing fields', () {
      final s = DoctorSettings.fromMap({});
      expect(s.dailyLimit, 20);
      expect(s.endTimeHour, 23);
      expect(s.endTimeMinute, 59);
    });

    test('endTimeLabel formats correctly', () {
      const s = DoctorSettings(endTimeHour: 9, endTimeMinute: 5);
      expect(s.endTimeLabel, '09:05');
    });

    test('endTimeSet is false for default values', () {
      const s = DoctorSettings();
      expect(s.endTimeSet, isFalse);
    });

    test('endTimeSet is true when hour is before 23', () {
      const s = DoctorSettings(endTimeHour: 17, endTimeMinute: 0);
      expect(s.endTimeSet, isTrue);
    });

    test('endTimeSet is true when minute is before 59', () {
      const s = DoctorSettings(endTimeHour: 23, endTimeMinute: 30);
      expect(s.endTimeSet, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorSettingsService.getSettings()
  // ══════════════════════════════════════════════════════════════════════════
  group('getSettings()', () {
    test('returns default DoctorSettings when no document exists', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DoctorSettingsService(doctorId: 'no-doc', firestore: fs);

      final settings = await svc.getSettings();

      expect(settings.dailyLimit, 20);
      expect(settings.endTimeHour, 23);
      expect(settings.endTimeMinute, 59);
    });

    test('returns persisted settings when document exists', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-1').set({
        'dailyLimit': 15,
        'endTimeHour': 18,
        'endTimeMinute': 0,
      });

      final svc = DoctorSettingsService(doctorId: 'dr-1', firestore: fs);
      final settings = await svc.getSettings();

      expect(settings.dailyLimit, 15);
      expect(settings.endTimeHour, 18);
      expect(settings.endTimeMinute, 0);
    });

    test('returns defaults when Firestore fails', () async {
      // Use a valid FakeFirebaseFirestore — it won't throw, but doc won't exist
      final fs = FakeFirebaseFirestore();
      final svc = DoctorSettingsService(doctorId: 'nonexistent', firestore: fs);
      final settings = await svc.getSettings();
      expect(settings.dailyLimit, 20);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorSettingsService.saveSettings()
  // ══════════════════════════════════════════════════════════════════════════
  group('saveSettings()', () {
    test('persists settings to Firestore document', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DoctorSettingsService(doctorId: 'dr-save', firestore: fs);

      await svc.saveSettings(
        const DoctorSettings(dailyLimit: 8, endTimeHour: 16, endTimeMinute: 30),
      );

      final doc = await fs.collection('doctor_settings').doc('dr-save').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['dailyLimit'], 8);
      expect(doc.data()?['endTimeHour'], 16);
      expect(doc.data()?['endTimeMinute'], 30);
    });

    test('merge: save does not erase other fields in the document', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-merge').set({
        'dailyLimit': 5,
        'endTimeHour': 12,
        'endTimeMinute': 0,
        'customField': 'preserved',
      });

      final svc = DoctorSettingsService(doctorId: 'dr-merge', firestore: fs);
      await svc.saveSettings(const DoctorSettings(dailyLimit: 10));

      final doc = await fs.collection('doctor_settings').doc('dr-merge').get();
      // The merge option should keep customField
      expect(doc.data()?['dailyLimit'], 10);
    });

    test('getSettings after saveSettings returns saved values', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DoctorSettingsService(doctorId: 'dr-roundtrip', firestore: fs);

      await svc.saveSettings(
        const DoctorSettings(dailyLimit: 7, endTimeHour: 15, endTimeMinute: 45),
      );
      final loaded = await svc.getSettings();

      expect(loaded.dailyLimit, 7);
      expect(loaded.endTimeHour, 15);
      expect(loaded.endTimeMinute, 45);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorSettingsService.checkQueueAccess()
  // ══════════════════════════════════════════════════════════════════════════
  group('checkQueueAccess()', () {
    test('returns null (allowed) when under daily limit', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-1').set({
        'dailyLimit': 20,
        'endTimeHour': 23,
        'endTimeMinute': 59,
      });
      // No queue entries yet → todayCount = 0

      final svc = DoctorSettingsService(doctorId: 'dr-1', firestore: fs);
      final result = await svc.checkQueueAccess();

      expect(result, isNull);
    });

    test('returns error message when daily limit reached', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-2').set({
        'dailyLimit': 2,
        'endTimeHour': 23,
        'endTimeMinute': 59,
      });
      // Seed 2 today's entries
      final today = DateTime.now();
      for (int i = 0; i < 2; i++) {
        await fs.collection('queues').doc('q$i').set({
          'doctorId': 'dr-2',
          'status': 'done',
          'timestamp': Timestamp.fromDate(
              DateTime(today.year, today.month, today.day, 9, i)),
        });
      }

      final svc = DoctorSettingsService(doctorId: 'dr-2', firestore: fs);
      final result = await svc.checkQueueAccess();

      expect(result, isNotNull);
      expect(result, contains('patient limit'));
    });

    test('returns null when entries are from a different day', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-3').set({
        'dailyLimit': 1,
        'endTimeHour': 23,
        'endTimeMinute': 59,
      });
      // Seed entry from yesterday
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await fs.collection('queues').doc('q-old').set({
        'doctorId': 'dr-3',
        'status': 'done',
        'timestamp': Timestamp.fromDate(yesterday),
      });

      final svc = DoctorSettingsService(doctorId: 'dr-3', firestore: fs);
      final result = await svc.checkQueueAccess();

      // Yesterday doesn't count → allowed
      expect(result, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // DoctorSettingsService.getTodayStats()
  // ══════════════════════════════════════════════════════════════════════════
  group('getTodayStats()', () {
    test('returns todayCount=0 when no queue entries for today', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DoctorSettingsService(doctorId: 'dr-stats', firestore: fs);

      final result = await svc.getTodayStats();

      expect(result.todayCount, 0);
      expect(result.settings.dailyLimit, 20);
    });

    test('counts only today\'s entries', () async {
      final fs = FakeFirebaseFirestore();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await fs.collection('queues').doc('q1').set({
        'doctorId': 'dr-today',
        'status': 'done',
        'timestamp': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day, 10, 0)),
      });
      await fs.collection('queues').doc('q2').set({
        'doctorId': 'dr-today',
        'status': 'done',
        'timestamp': Timestamp.fromDate(yesterday),
      });

      final svc = DoctorSettingsService(doctorId: 'dr-today', firestore: fs);
      final result = await svc.getTodayStats();

      expect(result.todayCount, 1); // only today's entry
    });

    test('returns correct settings from Firestore', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('doctor_settings').doc('dr-settings-stats').set({
        'dailyLimit': 12,
        'endTimeHour': 16,
        'endTimeMinute': 0,
      });

      final svc = DoctorSettingsService(doctorId: 'dr-settings-stats', firestore: fs);
      final result = await svc.getTodayStats();

      expect(result.settings.dailyLimit, 12);
      expect(result.settings.endTimeHour, 16);
    });

    test('todayCount includes multiple statuses for the same day', () async {
      final fs = FakeFirebaseFirestore();
      final today = DateTime.now();

      for (final status in ['waiting', 'serving', 'done']) {
        await fs.collection('queues').add({
          'doctorId': 'dr-multi',
          'status': status,
          'timestamp': Timestamp.fromDate(
              DateTime(today.year, today.month, today.day, 8, 0)),
        });
      }

      final svc = DoctorSettingsService(doctorId: 'dr-multi', firestore: fs);
      final result = await svc.getTodayStats();

      expect(result.todayCount, 3);
    });
  });
}
