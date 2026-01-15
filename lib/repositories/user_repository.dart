// lib/repositories/user_repository.dart
import 'dart:async';
import 'dart:math'; // ✅ ADD THIS for sin, cos, sqrt, asin
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'dart:io'; // ✅ ADD THIS
import 'package:firebase_storage/firebase_storage.dart'; // ✅ ADD THIS

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  /// Watch user document changes with improved error handling
  Stream<UserModel?> watchUser(String userId) {
    debugPrint('🔍 watchUser: Starting stream for $userId');
    debugPrint('🔍 Auth state: ${FirebaseAuth.instance.currentUser?.uid}');

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .timeout(
          const Duration(seconds: 30), // Increased timeout
          onTimeout: (sink) {
            debugPrint('⚠️ watchUser: Network slow for $userId, continuing to wait...');
            // Don't close the sink - let it keep trying
          },
        )
        .map((snapshot) {
          debugPrint('📡 Snapshot received for $userId: exists=${snapshot.exists}');
          
          if (!snapshot.exists) {
            debugPrint('❌ User document does not exist: $userId');
            return null;
          }

          try {
            final data = snapshot.data();
            if (data == null) {
              debugPrint('⚠️ User document has no data: $userId');
              return null;
            }

            final user = UserModel.fromFirestore(snapshot);
            debugPrint('✅ User ${user.name} (${user.role}) loaded successfully');
            return user;
          } catch (e, stack) {
            debugPrint('❌ Error parsing user data: $e');
            debugPrint('Stack: $stack');
            return null;
          }
        })
        .handleError((error, stack) {
          debugPrint('❌ Error in watchUser stream: $error');
          
          // Check for specific error types
          if (error.toString().contains('PERMISSION_DENIED')) {
            debugPrint('🚫 Firestore permission denied - check security rules');
          } else if (error.toString().contains('UNAVAILABLE')) {
            debugPrint('📡 Firestore unavailable - network issue');
          } else if (error.toString().contains('NOT_FOUND')) {
            debugPrint('🔍 User document not found');
          }
          
          // Don't rethrow - just log and let stream continue
        });
  }

  /// Get user once (for one-time reads)
  Future<UserModel?> getUser(String userId) async {
    try {
      debugPrint('📥 getUser: Fetching $userId');
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        debugPrint('❌ User document not found: $userId');
        return null;
      }

      final user = UserModel.fromFirestore(doc);
      debugPrint('✅ User ${user.name} fetched successfully');
      return user;
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      rethrow;
    }
  }

  /// Create a new user document
  /// Create a new user document
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('➕ Creating user: ${user.uid}');
      
      // ✅ FIXED: Convert UserModel to Map manually (no privacySettings/badges in model)
      final userData = <String, dynamic>{
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'photoUrl': user.photoUrl,
        'bio': user.bio,
        'specialization': user.specialization,
        'phoneNumber': user.phoneNumber,
        'addressLat': user.addressLat,
        'addressLng': user.addressLng,
        'addressText': user.addressText,
        'rating': user.rating ?? 0.0,
        'followerCount': user.followerCount ?? 0,
        'followingCount': user.followingCount ?? 0,
        'reviewCount': user.reviewCount ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData)
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ User created successfully');
    } catch (e) {
      debugPrint('❌ Error creating user: $e');
      rethrow;
    }
  }

  /// Update user document
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Updating user: $userId with ${data.keys}');
      await _firestore
          .collection('users')
          .doc(userId)
          .update(data)
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ User updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating user: $e');
      rethrow;
    }
  }

  /// Delete user document
  Future<void> deleteUser(String userId) async {
    try {
      debugPrint('🗑️ Deleting user: $userId');
      await _firestore
          .collection('users')
          .doc(userId)
          .delete()
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ User deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting user: $e');
      rethrow;
    }
  }

  /// Search users by role
  Future<List<UserModel>> searchUsersByRole(String role) async {
    try {
      debugPrint('🔍 Searching users with role: $role');
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get()
          .timeout(const Duration(seconds: 10));

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
      
      debugPrint('✅ Found ${users.length} users with role $role');
      return users;
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      rethrow;
    }
  }

  /// Get nearby mohaffez (users with role='mohaffez' and location set)
  Future<List<UserModel>> getNearbyMohaffez({
    required double userLat,
    required double userLng,
    double radiusKm = 50,
  }) async {
    try {
      debugPrint('🔍 Searching nearby mohaffez within ${radiusKm}km');
      
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mohaffez')
          .where('addressLat', isNotEqualTo: null)
          .get()
          .timeout(const Duration(seconds: 15));

      final mohaffezList = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) {
            if (user.addressLat == null || user.addressLng == null) {
              return false;
            }
            // Simple distance calculation (approximate)
            final distance = _calculateDistance(
              userLat,
              userLng,
              user.addressLat!,
              user.addressLng!,
            );
            return distance <= radiusKm;
          })
          .toList();

      debugPrint('✅ Found ${mohaffezList.length} nearby mohaffez');
      return mohaffezList;
    } catch (e) {
      debugPrint('❌ Error getting nearby mohaffez: $e');
      rethrow;
    }
  }

  /// Simple distance calculation (Haversine formula)
  /// ✅ FIXED: Import dart:math and use correct methods
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = 
        sin(dLat / 2) * sin(dLat / 2) +  // ✅ sin from dart:math
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *  // ✅ cos from dart:math
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));  // ✅ asin and sqrt from dart:math
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180.0);  // ✅ pi from dart:math
  }

  /// Update user's FCM token
  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token updated for $userId');
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
      // Don't rethrow - FCM token update is not critical
    }
  }

  /// Update follower counts
  Future<void> incrementFollowerCount(String mohaffezId) async {
    try {
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Error incrementing follower count: $e');
      rethrow;
    }
  }

  Future<void> decrementFollowerCount(String mohaffezId) async {
    try {
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('❌ Error decrementing follower count: $e');
      rethrow;
    }
  }

  /// Get user's public profile info (limited fields)
  Future<Map<String, dynamic>?> getUserPublicInfo(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'uid': userId,
        'name': data['name'],
        'photoUrl': data['photoUrl'],
        'role': data['role'],
        'bio': data['bio'],
        'specialization': data['specialization'],
        'rating': data['rating'],
        'followerCount': data['followerCount'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting public info: $e');
      return null;
    }
  }
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      debugPrint('📤 Uploading profile photo for $userId');
      
      // Import dart:io and firebase_storage at the top
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$userId.jpg');
      
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update user document with new photo URL
      await updateUser(userId, {'photoUrl': downloadUrl});
      
      debugPrint('✅ Profile photo uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// Update user profile (alias for updateUser)
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    return updateUser(userId, data);
  }

  /// Update user location
  Future<void> updateLocation({
    required String userId,
    required double lat,
    required double lng,
    required String addressText,
  }) async {
    try {
      await updateUser(userId, {
        'addressLat': lat,
        'addressLng': lng,
        'addressText': addressText,
      });
      debugPrint('✅ Location updated for $userId');
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      rethrow;
    }
  }
}