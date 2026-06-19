import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorModel {
  final String uid;
  final String name;
  final String specialization;
  final String clinicRoom;
  final int dailyLimit;

  DoctorModel({
    required this.uid,
    required this.name,
    required this.specialization,
    required this.clinicRoom,
    required this.dailyLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialization': specialization,
      'clinicRoom': clinicRoom,
      'dailyLimit': dailyLimit,
    };
  }

  factory DoctorModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DoctorModel(
      uid: doc.id,
      name: data['name'] ?? '',
      specialization: data['specialization'] ?? '',
      clinicRoom: data['clinicRoom'] ?? '',
      dailyLimit: data['dailyLimit'] ?? 20, // Default to 20 if not set
    );
  }
}