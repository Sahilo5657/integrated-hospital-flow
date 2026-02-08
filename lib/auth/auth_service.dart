import 'dart:math';
import 'package:flutter/foundation.dart';
import '../demo/demo_data.dart';
import '../models/user_profile.dart';
import '../models/queue_models.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  /// Shared queue state (simulates real-time for the defence demo)
  final ValueNotifier<List<QueueItem>> queue = ValueNotifier<List<QueueItem>>(DemoData.initialQueue());

  int dailyLimit = 50;

  void logout() => currentUser.value = null;

  void loginDemo({
    required String name,
    required String email,
    required UserRole role,
  }) {
    final uid = "U-${Random().nextInt(999999).toString().padLeft(6, '0')}";
    currentUser.value = UserProfile(uid: uid, name: name, email: email, role: role);
  }

  void registerPatientDemo({
    required String name,
    required String email,
  }) {
    loginDemo(name: name, email: email, role: UserRole.patient);
  }

  /// Patient taps "Join Queue" (demo replacement for NFC check-in)
  void joinQueueDemo(String patientName) {
    final list = [...queue.value];

    final alreadyActive = list.any((q) =>
        q.patientName.toLowerCase() == patientName.toLowerCase() &&
        (q.status == QueueStatus.waiting || q.status == QueueStatus.serving));
    if (alreadyActive) return;

    final lastToken = list.fold<int>(0, (m, e) => e.tokenNo > m ? e.tokenNo : m);
    final newToken = lastToken + 1;

    final waitingCount = list.where((e) => e.status == QueueStatus.waiting).length;
    final eta = waitingCount * 6;

    list.add(QueueItem(
      tokenNo: newToken,
      patientName: patientName,
      patientId: "P-${1000 + newToken}",
      etaMins: eta,
    ));

    queue.value = _recalculateEta(list);
  }

  /// Doctor taps "Call Next"
  void callNextDemo() {
    final list = [...queue.value];

    final servingIndex = list.indexWhere((e) => e.status == QueueStatus.serving);
    if (servingIndex != -1) list[servingIndex].status = QueueStatus.done;

    final nextIndex = list.indexWhere((e) => e.status == QueueStatus.waiting);
    if (nextIndex != -1) list[nextIndex].status = QueueStatus.serving;

    queue.value = _recalculateEta(list);
  }

  List<QueueItem> _recalculateEta(List<QueueItem> list) {
    int waitCounter = 0;
    final updated = <QueueItem>[];

    for (final item in list) {
      if (item.status == QueueStatus.serving) {
        updated.add(QueueItem(
          tokenNo: item.tokenNo,
          patientName: item.patientName,
          patientId: item.patientId,
          etaMins: 0,
          status: item.status,
        ));
      } else if (item.status == QueueStatus.waiting) {
        waitCounter += 6;
        updated.add(QueueItem(
          tokenNo: item.tokenNo,
          patientName: item.patientName,
          patientId: item.patientId,
          etaMins: waitCounter,
          status: item.status,
        ));
      } else {
        updated.add(item);
      }
    }
    return updated;
  }
}
