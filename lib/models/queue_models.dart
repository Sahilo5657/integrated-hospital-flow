import 'package:cloud_firestore/cloud_firestore.dart';

enum QueueStatus { waiting, serving, done, skipped }

extension QueueStatusX on QueueStatus {
  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }
}

class QueueItem {
  final String id; // Document ID
  final int tokenNo;
  final String patientName;
  final String patientId;
  final int etaMins;
  QueueStatus status;
  final DateTime timestamp;

  QueueItem({
    required this.id,
    required this.tokenNo,
    required this.patientName,
    required this.patientId,
    required this.etaMins,
    this.status = QueueStatus.waiting,
    required this.timestamp,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'tokenNo': tokenNo,
      'patientName': patientName,
      'patientId': patientId,
      'etaMins': etaMins,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory QueueItem.fromMap(Map<String, dynamic> data, String id) {
    return QueueItem(
      id: id,
      tokenNo: data['tokenNo'] ?? 0,
      patientName: data['patientName'] ?? 'Unknown',
      patientId: data['patientId'] ?? 'N/A',
      etaMins: data['etaMins'] ?? 0,
      status: QueueStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'waiting'),
        orElse: () => QueueStatus.waiting,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory QueueItem.fromFirestore(DocumentSnapshot doc) =>
      QueueItem.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
}