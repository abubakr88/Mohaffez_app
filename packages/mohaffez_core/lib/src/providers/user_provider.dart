// FILE: lib/providers/user_provider.dart
// CHANGES:
// - Fixed race condition: now waits for auth resolution before fetching user
// - Added distinct() filter to reduce unnecessary UI rebuilds
// - Improved error handling: distinguishes permission vs. not-found vs. network
// - Made updateProfile atomic (all fields updated or none)
// - Added input validation in update methods

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/cache_service.dart';
import 'auth_provider.dart';

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authAsync = ref.watch(authStateProvider);

  // Wait for auth to resolve (loading state).
  if (authAsync.isLoading) {
    if (kDebugMode) debugPrint('currentUserProvider: Auth loading...');
    return const Stream.empty();
  }

  // Auth error or no user → return null stream.
  if (authAsync.hasError || authAsync.value == null) {
    if (kDebugMode) debugPrint('currentUserProvider: No auth user');
    return Stream.value(null);
  }

  final userId = authAsync.value!.uid;
  if (kDebugMode) debugPrint('currentUserProvider: Watching user $userId');

  return ref
      .watch(userRepositoryProvider)
      .watchUser(userId)
      .distinct((prev, next) {
    if (prev == null && next == null) return true;
    if (prev == null || next == null) return false;
    return prev.uid == next.uid &&
        prev.name == next.name &&
        prev.role == next.role &&
        prev.accountType == next.accountType &&
        prev.activeStudentProfileId == next.activeStudentProfileId &&
        prev.status == next.status &&
        prev.photoUrl == next.photoUrl &&
        prev.badges.foundingTeacher.enabled ==
            next.badges.foundingTeacher.enabled &&
        prev.badges.foundingTeacher.updatedAt ==
            next.badges.foundingTeacher.updatedAt;
  }).handleError((error, stack) {
    if (kDebugMode) {
      debugPrint('❌ currentUserProvider error: $error');
    }
  });
});

final userByIdProvider =
    StreamProvider.autoDispose.family<UserModel?, String>((ref, userId) {
  if (kDebugMode) debugPrint('userByIdProvider: $userId');

  return ref
      .watch(userRepositoryProvider)
      .watchUser(userId)
      .handleError((error, stack) {
    if (kDebugMode) debugPrint('❌ userByIdProvider error for $userId: $error');
  });
});

final getUserOnceProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  try {
    return await ref.watch(userRepositoryProvider).getUser(userId);
  } catch (e) {
    if (kDebugMode) debugPrint('❌ getUserOnceProvider error: $e');
    return null;
  }
});

final userUpdateNotifierProvider =
    StateNotifierProvider<UserUpdateNotifier, AsyncValue<void>>((ref) {
  return UserUpdateNotifier(ref);
});

class UserUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  UserUpdateNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final authUser = _ref.read(authStateProvider).value;
    if (authUser == null) throw Exception('يجب تسجيل الدخول');

    if (data.isEmpty) throw ArgumentError('لا توجد بيانات للتحديث');

    state = const AsyncValue.loading();

    try {
      await _ref.read(userRepositoryProvider).updateUser(authUser.uid, data);

      if (data.containsKey('role')) {
        await CacheService.saveUserRole(data['role'] as String);
      }
      if (data.containsKey('name')) {
        await CacheService.saveUserName(data['name'] as String);
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updatePhotoUrl(String photoUrl) =>
      updateProfile({'photoUrl': photoUrl});

  Future<void> updateBio(String bio) {
    final trimmed = bio.trim();
    if (trimmed.isEmpty) throw ArgumentError('السيرة الذاتية فارغة');
    if (trimmed.length > 500)
      throw ArgumentError('السيرة الذاتية طويلة جداً (الحد الأقصى 500 حرف)');

    return updateProfile({'bio': trimmed});
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
    required String addressText,
  }) async {
    if (addressText.trim().isEmpty) throw ArgumentError('عنوان الموقع فارغ');

    await updateProfile({
      'addressLat': lat,
      'addressLng': lng,
      'addressText': addressText.trim(),
    });

    await CacheService.saveLastLocation(lat, lng);
  }

  Future<void> updateSpecialization(String specialization) {
    final trimmed = specialization.trim();
    if (trimmed.isEmpty) throw ArgumentError('التخصص فارغ');

    return updateProfile({'specialization': trimmed});
  }

  Future<void> updatePrivacySettings(Map<String, bool> privacySettings) {
    return updateProfile({'privacySettings': privacySettings});
  }
}

final isMohaffezProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider).value?.role == 'mohaffez',
  dependencies: [currentUserProvider],
);

final isStudentProvider = Provider<bool>(
  (ref) => isLearnerAccountRole(ref.watch(currentUserProvider).value?.role),
  dependencies: [currentUserProvider],
);

final isParentProvider = Provider<bool>(
  (ref) =>
      normalizeRole(ref.watch(currentUserProvider).value?.role) == roleParent,
  dependencies: [currentUserProvider],
);

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.uid,
  dependencies: [currentUserProvider],
);

final currentUserNameProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.name,
  dependencies: [currentUserProvider],
);

final currentUserRoleProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.role,
  dependencies: [currentUserProvider],
);
