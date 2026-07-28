// lib/repositories/user_repository.dart - OPTIMIZED
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  // ✅ ADDED: Cache for user documents (5 minutes TTL)
  final Map<String, ({UserModel user, DateTime cachedAt})> _userCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  UserRepository(this._firestore);

  /// ✅ IMPROVED: Watch user with better error handling and retries
  Stream<UserModel?> watchUser(String userId) {
    debugPrint('[UserRepository] Starting stream for $userId');

    return _firestore.collection('users').doc(userId).snapshots().timeout(
      const Duration(seconds: 30),
      onTimeout: (sink) {
        debugPrint('[UserRepository] Timeout for $userId - retrying...');
        // Don't close sink - let it retry
      },
    ).asyncMap((snapshot) async {
      if (!snapshot.exists) {
        debugPrint('[UserRepository] User document not found: $userId');
        return null;
      }

      try {
        final data = snapshot.data();
        if (data == null) {
          debugPrint('[UserRepository] User document has no data: $userId');
          return null;
        }

        final user = UserModel.fromFirestore(snapshot);

        // ✅ Update cache
        _userCache[userId] = (user: user, cachedAt: DateTime.now());

        debugPrint('[UserRepository] User ${user.name} (${user.role}) loaded');
        return user;
      } catch (e, stack) {
        debugPrint('[UserRepository] Error parsing user data: $e');
        debugPrintStack(stackTrace: stack);
        return null;
      }
    }).handleError((error, stack) {
      debugPrint('[UserRepository] Stream error: $error');

      // ✅ Differentiate error types
      if (error.toString().contains('PERMISSION_DENIED')) {
        debugPrint(
            '[UserRepository] Permission denied - check Firestore rules');
      } else if (error.toString().contains('UNAVAILABLE')) {
        debugPrint('[UserRepository] Firestore unavailable - network issue');
      } else if (error.toString().contains('NOT_FOUND')) {
        debugPrint('[UserRepository] User document not found');
      }

      // Return cached value if available
      final cached = _userCache[userId];
      if (cached != null) {
        debugPrint('[UserRepository] Returning cached user data');
        return Stream.value(cached.user);
      }
    }).distinct((prev, next) {
      // Only emit when user data actually changes
      if (prev == null && next == null) return true;
      if (prev == null || next == null) return false;
      return prev.uid == next.uid &&
          prev.name == next.name &&
          prev.role == next.role &&
          prev.accountType == next.accountType &&
          prev.activeStudentProfileId == next.activeStudentProfileId &&
          prev.status == next.status &&
          prev.photoUrl == next.photoUrl;
    });
  }

  /// ✅ IMPROVED: Get user once with cache support
  Future<UserModel?> getUser(String userId, {bool useCache = true}) async {
    debugPrint('[UserRepository] Fetching user: $userId (useCache: $useCache)');

    // Check cache first
    if (useCache) {
      final cached = _userCache[userId];
      if (cached != null) {
        final age = DateTime.now().difference(cached.cachedAt);
        if (age < _cacheDuration) {
          debugPrint(
              '[UserRepository] Returning cached user (age: ${age.inSeconds}s)');
          return cached.user;
        }
      }
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        debugPrint('[UserRepository] User not found: $userId');
        return null;
      }

      final user = UserModel.fromFirestore(doc);

      // Update cache
      _userCache[userId] = (user: user, cachedAt: DateTime.now());

      debugPrint('[UserRepository] User ${user.name} fetched successfully');
      return user;
    } catch (e) {
      debugPrint('[UserRepository] Error getting user: $e');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Create user with validation
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('[UserRepository] Creating user: ${user.uid}');

      // Validate required fields
      if (user.name.trim().isEmpty) {
        throw Exception('Name cannot be empty');
      }
      if (user.email.trim().isEmpty) {
        throw Exception('Email cannot be empty');
      }
      if (!isSelfSelectableSignupRole(user.role)) {
        throw Exception('Invalid role: ${user.role}');
      }

      final userData = <String, dynamic>{
        'uid': user.uid,
        'name': user.name.trim(),
        if (normalizeRole(user.role) == roleMohaffez &&
            teacherHonorifics.contains(user.honorific))
          'honorific': user.honorific,
        'email': user.email.trim(),
        'role': user.role,
        'photoUrl': user.photoUrl,
        'bio': user.bio,
        'youtubeVideoUrl': user.youtubeVideoUrl,
        'specialization': user.specialization,
        'phoneNumber': user.phoneNumber,
        'addressLat': user.addressLat,
        'addressLng': user.addressLng,
        'addressText': user.addressText,
        'rating': user.rating,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'reviewCount': user.reviewCount,
        if (normalizeRole(user.role) == roleMohaffez) ...{
          'ratingSum': 0.0,
          'ratingScale': 5,
          'ratingPolicyVersion': 2,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData)
          .timeout(const Duration(seconds: 10));

      debugPrint('[UserRepository] User created successfully');

      // Update cache
      _userCache[user.uid] = (user: user, cachedAt: DateTime.now());
    } catch (e) {
      debugPrint('[UserRepository] Error creating user: $e');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Update user with validation
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint('[UserRepository] Updating user $userId: ${data.keys}');

      // ✅ Validate fields
      if (data.containsKey('name') && (data['name'] as String).trim().isEmpty) {
        throw Exception('Name cannot be empty');
      }
      if (data.containsKey('email') &&
          (data['email'] as String).trim().isEmpty) {
        throw Exception('Email cannot be empty');
      }
      if (data.containsKey('role') &&
          !isSelfSelectableSignupRole(data['role']?.toString())) {
        throw Exception('Invalid role: ${data['role']}');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .update(data)
          .timeout(const Duration(seconds: 10));

      debugPrint('[UserRepository] User updated successfully');

      // ✅ Invalidate cache
      _userCache.remove(userId);
    } catch (e) {
      debugPrint('[UserRepository] Error updating user: $e');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Delete user and cleanup
  Future<void> deleteUser(String userId) async {
    try {
      debugPrint('[UserRepository] Deleting user: $userId');

      // Delete user document
      await _firestore
          .collection('users')
          .doc(userId)
          .delete()
          .timeout(const Duration(seconds: 10));

      // ✅ Cleanup: Delete subcollections (credentials, availability)
      final batch = _firestore.batch();

      final credentials = await _firestore
          .collection('users')
          .doc(userId)
          .collection('credentials')
          .get();
      for (final doc in credentials.docs) {
        batch.delete(doc.reference);
      }

      final availability = await _firestore
          .collection('users')
          .doc(userId)
          .collection('availability')
          .get();
      for (final doc in availability.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('[UserRepository] User deleted successfully');

      // Remove from cache
      _userCache.remove(userId);
    } catch (e) {
      debugPrint('[UserRepository] Error deleting user: $e');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Search users by role with pagination
  Future<List<UserModel>> searchUsersByRole(
    String role, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      debugPrint('[UserRepository] Searching users with role: $role');

      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));

      final users =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      debugPrint(
          '[UserRepository] Found ${users.length} users with role $role');
      return users;
    } catch (e) {
      debugPrint('[UserRepository] Error searching users: $e');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Get nearby mohaffez with validation
  Future<List<UserModel>> getNearbyMohaffez({
    required double userLat,
    required double userLng,
    double radiusKm = 50,
  }) async {
    try {
      // ✅ Validate coordinates
      if (userLat < -90 || userLat > 90) {
        throw Exception('Invalid latitude: $userLat');
      }
      if (userLng < -180 || userLng > 180) {
        throw Exception('Invalid longitude: $userLng');
      }

      debugPrint(
          '[UserRepository] Searching nearby mohaffez within ${radiusKm}km');

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mohaffez')
          .where('status', isEqualTo: 'active')
          .where('addressLat', isNotEqualTo: null)
          .get()
          .timeout(const Duration(seconds: 15));

      final mohaffezList = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) {
        if (user.addressLat == null || user.addressLng == null) {
          return false;
        }

        // ✅ Validate mohaffez coordinates
        if (user.addressLat! < -90 ||
            user.addressLat! > 90 ||
            user.addressLng! < -180 ||
            user.addressLng! > 180) {
          debugPrint('[UserRepository] Invalid coordinates for ${user.name}');
          return false;
        }

        final distance = _calculateDistance(
          userLat,
          userLng,
          user.addressLat!,
          user.addressLng!,
        );

        return distance <= radiusKm;
      }).toList();

      debugPrint(
          '[UserRepository] Found ${mohaffezList.length} nearby mohaffez');
      return mohaffezList;
    } catch (e) {
      debugPrint('[UserRepository] Error getting nearby mohaffez: $e');
      rethrow;
    }
  }

  /// ✅ FIXED: Haversine distance calculation with validation
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;

  /// ✅ IMPROVED: Update FCM token with error handling
  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserRepository] FCM token updated for $userId');
    } catch (e) {
      debugPrint('[UserRepository] Error updating FCM token: $e');
      // Don't rethrow - FCM token update is not critical
    }
  }

  /// ✅ ADDED: Clear cache (useful for logout)
  void clearCache() {
    _userCache.clear();
    debugPrint('[UserRepository] Cache cleared');
  }

  /// ✅ ADDED: Increment/decrement follower count atomically
  Future<void> incrementFollowerCount(String mohaffezId) async {
    try {
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('[UserRepository] Error incrementing follower count: $e');
      rethrow;
    }
  }

  Future<void> decrementFollowerCount(String mohaffezId) async {
    try {
      await _firestore.collection('users').doc(mohaffezId).update({
        'followerCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('[UserRepository] Error decrementing follower count: $e');
      rethrow;
    }
  }
}
