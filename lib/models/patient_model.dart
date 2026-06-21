import 'package:cloud_firestore/cloud_firestore.dart';

class PatientModel {
  final String uid;
  final String name;
  final String contact;
  final String? nfcCardId;
  final DateTime createdAt;

  PatientModel({
    required this.uid,
    required this.name,
    required this.contact,
    this.nfcCardId,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'nfcCardId': nfcCardId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> data, String id) {
    return PatientModel(
      uid: id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      nfcCardId: data['nfcCardId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  factory PatientModel.fromFirestore(DocumentSnapshot doc) =>
      PatientModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
}