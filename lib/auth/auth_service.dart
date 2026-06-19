import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // This import gives you access to 'ChangeNotifier'
import '../models/user_profile.dart';

// By adding 'extends ChangeNotifier', this class can now tell the UI to rebuild
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<void> signUp(String email, String password, String name, String role, {String? nfcCardId}) async {
    try {
      if (role == 'patient') {
        if (nfcCardId == null || nfcCardId.isEmpty) {
          throw Exception("NFC Card ID is required for patients.");
        }

        final cardDoc = await _firestore.collection('activated_cards').doc(nfcCardId).get();
        if (!cardDoc.exists) {
          throw Exception('This NFC Card has not been activated by staff.');
        }
        if (cardDoc.data()?['isLinkedToApp'] == true) {
          throw Exception('This card is already linked to an account.');
        }
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      UserProfile newUser = UserProfile(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
      );

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(userCredential.user!.uid), newUser.toMap());

      if (role == 'patient' && nfcCardId != null) {
        batch.update(_firestore.collection('activated_cards').doc(nfcCardId), {
          'isLinkedToApp': true,
          'linkedUid': userCredential.user!.uid,
        });
      }

      await batch.commit();

      // 'notifyListeners()' tells any UI listening to this service to refresh
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Sign In
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> joinQueue(String name, String uid) async {
    try {
      // 1. Check for duplicates
      final existingQuery = await _firestore.collection('queues')
          .where('patientId', isEqualTo: uid)
          .where('status', whereIn: ['waiting', 'serving'])
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception("You are already in the queue.");
      }

      // 2. Add to queue
      // Get the highest token number to increment it (simple logic)
      final lastQueue = await _firestore.collection('queues')
          .orderBy('tokenNo', descending: true)
          .limit(1)
          .get();

      int newTokenNo = 1;
      if (lastQueue.docs.isNotEmpty) {
        newTokenNo = (lastQueue.docs.first.data()['tokenNo'] as int) + 1;
      }

      await _firestore.collection('queues').add({
        'patientName': name,
        'patientId': uid,
        'tokenNo': newTokenNo,
        'status': 'waiting',
        'etaMins': 15, // Default ETA
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Get user profile as a Stream (more robust than Future for role-based routing)
  Stream<UserProfile?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    }).handleError((e) {
      debugPrint("Error in userProfileStream: $e");
      return null;
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    }
  }

  // "Call Next" logic: Move current 'serving' to 'done' and oldest 'waiting' to 'serving'
  Future<void> callNext() async {
    try {
      final batch = _firestore.batch();

      // 1. Mark current serving as done
      final servingQuery = await _firestore.collection('queues')
          .where('status', isEqualTo: 'serving')
          .get();

      for (var doc in servingQuery.docs) {
        batch.update(doc.reference, {'status': 'done'});
      }

      // 2. Find next in line
      final nextQuery = await _firestore.collection('queues')
          .where('status', isEqualTo: 'waiting')
          .orderBy('tokenNo', descending: false)
          .limit(1)
          .get();

      if (nextQuery.docs.isNotEmpty) {
        batch.update(nextQuery.docs.first.reference, {'status': 'serving'});
        await batch.commit();
      } else {
        // If no one is waiting, just commit the completion of current serving
        await batch.commit();
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Complete Visit logic: Mark current 'serving' as 'done', then immediately call next
  Future<void> completeVisit() async {
    try {
      final servingQuery = await _firestore.collection('queues')
          .where('status', isEqualTo: 'serving')
          .get();

      if (servingQuery.docs.isEmpty) {
        throw Exception("No patient is currently being served.");
      }

      final batch = _firestore.batch();
      for (var doc in servingQuery.docs) {
        batch.update(doc.reference, {'status': 'done', 'queueStatus': 'Done'});
      }
      await batch.commit();

      await callNext();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}