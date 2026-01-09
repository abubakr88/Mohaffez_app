import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/cache_service.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  UserRepository(this._firestore, this._storage);

  /// Get user by ID with caching
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) return null;

      final user = UserModel.fromJson({
        ...doc.data()!,
        'uid': doc.id,
      });

      // Cache user data
      await CacheService.saveUserRole(user.role);
      await CacheService.saveUserName(user.name);
      await CacheService.saveUserId(user.uid);

      return user;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Watch user changes in real-time
  Stream<UserModel?> watchUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      
      return UserModel.fromJson({
        ...doc.data()!,
        'uid': doc.id,
      });
    });
  }

  /// Update user profile
  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore.collection('users').doc(userId).update(updates);
  }

  /// Upload and update profile photo
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    final storageRef = _storage.ref().child('user_photos').child('$userId.jpg');
    await storageRef.putFile(imageFile);
    final url = await storageRef.getDownloadURL();
    
    await updateProfile(
      userId: userId,
      updates: {'photoUrl': url},
    );
    
    return url;
  }

  /// Update user location
  Future<void> updateLocation({
    required String userId,
    required String addressText,
    required double lat,
    required double lng,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'addressText': addressText,
      'addressLat': lat,
      'addressLng': lng,
    });

    await CacheService.saveLastLocation(lat, lng);
  }

  /// Refresh user data in background
  Future<void> refreshUser(String userId) async {
    // Silent refresh without throwing errors
    try {
      await getUser(userId);
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }
}
