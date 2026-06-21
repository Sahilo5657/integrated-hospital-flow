import 'package:cloud_firestore/cloud_firestore.dart';

class EncounterModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String clinicalNotes;
  final DateTime timestamp;

  EncounterModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.clinicalNotes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'patientId': patientId,
    'doctorId': doctorId,
    'clinicalNotes': clinicalNotes,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory EncounterModel.fromMap(Map<String, dynamic> data, String id) {
    return EncounterModel(
      id: id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      clinicalNotes: data['clinicalNotes'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  factory EncounterModel.fromFirestore(DocumentSnapshot doc) =>
      EncounterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
}