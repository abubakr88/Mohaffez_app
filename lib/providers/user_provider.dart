// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_provider.dart';
import '../services/cache_service.dart';

/// Provider for the current authenticated user's data
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;

  if (authUser == null) {
    debugPrint('currentUserProvider: No authenticated user');
    return Stream.value(null);
  }

  debugPrint('currentUserProvider: Starting for ${authUser.uid}');

  // Watch user document with retry logic
  return ref
      .watch(userRepositoryProvider)
      .watchUser(authUser.uid)
      .handleError((error, stack) {
        debugPrint('❌ currentUserProvider: Stream error: $error');
        
        // Log specific error types
        if (error.toString().contains('PERMISSION_DENIED')) {
          debugPrint('🚫 Permission denied - check Firestore rules');
        } else if (error.toString().contains('UNAVAILABLE')) {
          debugPrint('📡 Firestore unavailable - network issue');
        }
        
        // Don't throw - let the stream continue trying
      })
      .distinct((prev, next) {
        // Only emit when user data actually changes
        if (prev == null && next == null) return true;
        if (prev == null || next == null) return false;
        return prev.uid == next.uid && 
               prev.name == next.name && 
               prev.role == next.role;
      });
});

/// Provider for any user by ID (for viewing profiles)
final userByIdProvider = StreamProvider.family<UserModel?, String>((ref, userId) {
  debugPrint('userByIdProvider: Watching user $userId');
  
  return ref
      .watch(userRepositoryProvider)
      .watchUser(userId)
      .handleError((error, stack) {
        debugPrint('❌ userByIdProvider: Error for $userId: $error');
      });
});

/// Provider for getting user once (one-time fetch)
final getUserOnceProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  debugPrint('getUserOnceProvider: Fetching user $userId');
  
  try {
    final user = await ref.watch(userRepositoryProvider).getUser(userId);
    return user;
  } catch (e) {
    debugPrint('❌ getUserOnceProvider: Error fetching $userId: $e');
    return null;
  }
});

/// Notifier for user profile updates
final userUpdateNotifierProvider = StateNotifierProvider<UserUpdateNotifier, AsyncValue<void>>((ref) {
  return UserUpdateNotifier(ref);
});

class UserUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  UserUpdateNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Update current user's profile
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      throw Exception('No authenticated user');
    }

    state = const AsyncValue.loading();

    try {
      await ref.read(userRepositoryProvider).updateUser(authUser.uid, data);
      
      // Update cache
      if (data.containsKey('role')) {
        await CacheService.saveUserRole(data['role']);
      }
      if (data.containsKey('name')) {
        await CacheService.saveUserName(data['name']);
      }

      state = const AsyncValue.data(null);
      debugPrint('✅ Profile updated successfully');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// Update user's photo URL
  Future<void> updatePhotoUrl(String photoUrl) async {
    await updateProfile({'photoUrl': photoUrl});
  }

  /// Update user's bio
  Future<void> updateBio(String bio) async {
    await updateProfile({'bio': bio});
  }

  /// Update user's location
  Future<void> updateLocation({
    required double lat,
    required double lng,
    required String addressText,
  }) async {
    await updateProfile({
      'addressLat': lat,
      'addressLng': lng,
      'addressText': addressText,
    });

    // Update cache
    await CacheService.saveLastLocation(lat, lng);
  }

  /// Update user's specialization (for mohaffez)
  Future<void> updateSpecialization(String specialization) async {
    await updateProfile({'specialization': specialization});
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(Map<String, bool> privacySettings) async {
    await updateProfile({'privacySettings': privacySettings});
  }
}

/// Provider to check if current user is mohaffez
final isMohaffezProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role == 'mohaffez';
});

/// Provider to check if current user is student
final isStudentProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role == 'student';
});

/// Provider for current user's ID (convenience)
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.uid;
});

/// Provider for current user's name (convenience)
final currentUserNameProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.name;
});

/// Provider for current user's role (convenience)
final currentUserRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role;
});
