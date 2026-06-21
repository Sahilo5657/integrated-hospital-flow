import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

// ─── Action constants ────────────────────────────────────────────────────────
class AuditAction {
  AuditAction._();

  // Auth
  static const String userLogin         = 'USER_LOGIN';
  static const String userLogout        = 'USER_LOGOUT';
  static const String userRegistered    = 'USER_REGISTERED';

  // Queue
  static const String queueJoined       = 'QUEUE_JOINED';
  static const String queueCallNext     = 'QUEUE_CALL_NEXT';
  static const String queueVisitDone    = 'QUEUE_VISIT_COMPLETED';
  static const String queuePatientCalled = 'QUEUE_PATIENT_CALLED';

  // Patient records / AI
  static const String patientRecordViewed  = 'PATIENT_RECORD_VIEWED';
  static const String patientRecordSaved   = 'PATIENT_RECORD_SAVED';
  static const String aiSummaryViewed      = 'AI_SUMMARY_VIEWED';

  // NFC / staff
  static const String nfcCardScanned      = 'NFC_CARD_SCANNED';
  static const String nfcCardRegistered   = 'NFC_CARD_REGISTERED';
  static const String patientLookupNic    = 'PATIENT_LOOKUP_NIC';
  static const String nfcCardLinkedNic    = 'NFC_CARD_LINKED_NIC';

  // Backup
  static const String backupExported      = 'BACKUP_EXPORTED';
  static const String backupRestored      = 'BACKUP_RESTORED';
}

// ─── Service ─────────────────────────────────────────────────────────────────
class AuditLogService {
  final FirebaseFirestore _db;

  AuditLogService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Logs [action] to Firestore **and** a daily local file.
  /// Never throws — failures are silently swallowed so a log call never
  /// breaks the feature it is observing.
  Future<void> log({
    required String action,
    required String actor,   // email or UID of who triggered this
    required String role,    // 'patient' | 'doctor' | 'staff' | 'system'
    Map<String, dynamic>? details,
  }) async {
    final now = DateTime.now();
    final entry = <String, dynamic>{
      'action'    : action,
      'actor'     : actor,
      'role'      : role,
      'localTime' : now.toIso8601String(),
      'timestamp' : FieldValue.serverTimestamp(),
      if (details != null) ...details,
    };

    // ── Firestore (primary store) ─────────────────────────────────────────
    try {
      await _db.collection('audit_logs').add(entry);
    } catch (_) {
      // best-effort
    }

    // ── Local daily file (secondary store) ───────────────────────────────
    try {
      await _writeToFile(action, actor, role, now, details);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _writeToFile(
    String action,
    String actor,
    String role,
    DateTime now,
    Map<String, dynamic>? details,
  ) async {
    // Try external storage first (visible in file manager); fall back to internal.
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final logDir = Directory('${dir.path}/audit_logs');
    if (!logDir.existsSync()) logDir.createSync(recursive: true);

    final dateStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final file    = File('${logDir.path}/audit_log_$dateStr.txt');

    final timeStr = '${now.hour.toString().padLeft(2,'0')}:'
                    '${now.minute.toString().padLeft(2,'0')}:'
                    '${now.second.toString().padLeft(2,'0')}';

    final detailStr = details == null || details.isEmpty
        ? ''
        : ' | ${details.entries.map((e) => '${e.key}=${e.value}').join(' | ')}';

    final line = '[$dateStr $timeStr] $action | actor=$actor | role=$role$detailStr\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }
}
