// nfc_card_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NFCCardModel {
  final String cardId; // The unique ID read from the NFC chip (usually the doc ID)
  final String? assignedPatientId;
  final bool isActive;

  NFCCardModel({
    required this.cardId,
    this.assignedPatientId,
    this.isActive = true,
  });

  factory NFCCardModel.fromFirestore(Map<String, dynamic> data, String id) {
    return NFCCardModel(
      cardId: id,
      assignedPatientId: data['assignedPatientId'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'assignedPatientId': assignedPatientId,
        'isActive': isActive,
      };
}

// tap_log_model.dart
class TapLogModel {
  final String? logId;
  final String cardId;
  final String? patientId; // Captured at tap time for history
  final String readerDeviceId;
  final DateTime timestamp;

  TapLogModel({
    this.logId,
    required this.cardId,
    this.patientId,
    required this.readerDeviceId,
    required this.timestamp,
  });

  factory TapLogModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TapLogModel(
      logId: id,
      cardId: data['cardId'] ?? '',
      patientId: data['patientId'],
      readerDeviceId: data['readerDeviceId'] ?? 'unknown',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'cardId': cardId,
        'patientId': patientId,
        'readerDeviceId': readerDeviceId,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
