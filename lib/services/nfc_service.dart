import 'package:cloud_firestore/cloud_firestore.dart';

class NfService {
  final FirebaseFirestore _firestore;
  NfService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. Links a new physical card to a patient profile
  Future<void> registerAndActivateCard({
    required String cardId,
    required String patientName,
    required String phoneNumber,
  }) async {
    await _firestore.collection('activated_cards').doc(cardId).set({
      'cardId': cardId,
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      'status': 'active',
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Automatically drops an existing card holder into Dr. Sahil's waiting room
  Future<bool> checkInPatientToQueue(String cardId, String patientName) async {
    try {
      final queueRef = _firestore.collection('queues').doc();
      await queueRef.set({
        'queueId': queueRef.id,
        'doctorId': 'sahilo5657@gmail.com', // Permanently locked to your single doctor account
        'doctor_id': 'sahilo5657@gmail.com',
        'patientName': patientName,
        'status': 'waiting',
        'queueStatus': 'Waiting',
        'timestamp': FieldValue.serverTimestamp(),
        'isLinkedToApp': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}