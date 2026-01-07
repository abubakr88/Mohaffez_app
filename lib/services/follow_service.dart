import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Follow a mohaffez
  static Future<bool> followMohaffez(String mohaffezId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if already following
      final existingFollow = await _firestore
          .collection('follows')
          .where('studentId', isEqualTo: user.uid)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .get();

      if (existingFollow.docs.isNotEmpty) {
        return false; // Already following
      }

      // Create follow relationship
      await _firestore.collection('follows').add({
        'studentId': user.uid,
        'mohaffezId': mohaffezId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Increment mohaffez's follower count
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(1),
      });

      // Increment user's following count
      await _firestore.collection('users').doc(user.uid).update({
        'followingCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error following mohaffez: $e');
      return false;
    }
  }

  // Unfollow a mohaffez
  static Future<bool> unfollowMohaffez(String mohaffezId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Find follow relationship
      final followSnapshot = await _firestore
          .collection('follows')
          .where('studentId', isEqualTo: user.uid)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .get();

      if (followSnapshot.docs.isEmpty) {
        return false; // Not following
      }

      // Delete follow relationship
      for (final doc in followSnapshot.docs) {
        await doc.reference.delete();
      }

      // Decrement mohaffez's follower count
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(-1),
      });

      // Decrement user's following count
      await _firestore.collection('users').doc(user.uid).update({
        'followingCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      print('Error unfollowing mohaffez: $e');
      return false;
    }
  }

  // Check if user is following a mohaffez
  static Future<bool> isFollowing(String mohaffezId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final followSnapshot = await _firestore
          .collection('follows')
          .where('studentId', isEqualTo: user.uid)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .get();

      return followSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get follower count for a mohaffez
  static Future<int> getFollowerCount(String mohaffezId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(mohaffezId).get();
      return userDoc.data()?['followerCount'] as int? ?? 0;
    } catch (e) {
      print('Error getting follower count: $e');
      return 0;
    }
  }

  // Get list of followed mohaffezs
  static Stream<List<String>> getFollowedMohaffezs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('follows')
        .where('studentId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['mohaffezId'] as String)
          .toList();
    });
  }

  // Get list of followers for a mohaffez
  static Stream<QuerySnapshot<Map<String, dynamic>>> getFollowers(
      String mohaffezId) {
    return _firestore
        .collection('follows')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('followedAt', descending: true)
        .snapshots();
  }
}
