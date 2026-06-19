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

  // Create from Firestore
  factory PatientModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PatientModel(
      uid: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      nfcCardId: data['nfcCardId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}