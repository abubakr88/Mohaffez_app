// FILE: lib/providers/auth_provider.dart
// CHANGES:
// - Removed race condition between sign-in and user doc load by introducing retries
// - Made sign-in/sign-up transactional (cache only after Firestore doc exists)
// - Added null checks in AsyncValue.guard to prevent silent failures
// - Added exponential backoff for FCM token save
// - Fixed invalidation order (auth invalidated AFTER operations complete)
// - [FIX] Added 'uid' field to signUp Firestore write (required by security rule)
// - [FIX] Added 'status' field to match UserModel defaults
// - [FIX] Delete orphan Auth account if Firestore write fails in signUp

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/cache_service.dart';
import '../models/commission_tier_model.dart';
import '../models/user_model.dart';
import 'booking_flow_provider.dart';

/// Thrown when a new Google user has authenticated but has no Firestore doc yet.
/// The UI catches this and shows role/gender selection before calling
/// [AuthNotifier.completeGoogleSignIn].
class NeedsRoleSelectionException implements Exception {
  final String name;
  final String email;
  final String? photoUrl;

  const NeedsRoleSelectionException({
    required this.name,
    required this.email,
    this.photoUrl,
  });
}

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance
      .authStateChanges()
      .asyncMap((firebaseUser) async {
    if (firebaseUser != null) {
      try {
        await firebaseUser
            .getIdToken(false)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('authStateProvider: token refresh failed, using cached: $e');
        // Non-fatal: fall back silently, stream still resolves with the user
      }
    }
    return firebaseUser;
  });
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref)
      : super(const AsyncValue.data(null));

  Map<String, dynamic> _initialCommissionFields(String role) {
    if (role != 'mohaffez') return const <String, dynamic>{};
    final starterTier = CommissionTierModel.defaultTiers.first;
    return {
      'commissionRate': starterTier.rate,
      'commissionTier': starterTier.id,
      'commissionPenaltyPercent': 0,
      'tierStats': {
        'last14dRevenueEgp': 0,
        'sessionsLast14d': 0,
        'totalSessionsLast14d': 0,
        'lateSessionsLast14d': 0,
      },
    };
  }

  Future<void> _ensureTeacherRegistrationAllowed(String role) async {
    if (role != 'mohaffez') return;

    final doc = await FirebaseFirestore.instance
        .collection('systemConfig')
        .doc('global')
        .get();
    final enabled = doc.data()?['teacherRegistrationEnabled'] as bool? ?? true;
    if (!enabled) {
      throw Exception(
        'تسجيل المحفظين الجدد متوقف حالياً. يرجى المحاولة لاحقاً.',
      );
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final cred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user == null) throw Exception('فشل تسجيل الدخول');

      // WHY: Force immediate claim propagation after login (no 1-hour token wait).
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final userId = cred.user!.uid;

      // Wait for user doc with retry (Firestore may lag after auth).
      final userDoc = await _waitForUserDoc(userId, maxRetries: 3);

      if (!userDoc.exists) {
        await _authService.logout();
        throw Exception('حساب غير مكتمل. تواصل مع الدعم');
      }

      final data = userDoc.data() as Map<String, dynamic>;

      // ✅ FIX: Check suspension BEFORE caching — prevents white screen.
      // Check 1: users doc status field.
      // pending_approval / rejected are allowed to sign in so they can
      // be routed to /teacher-pending or /teacher-rejected by RoleGuard.
      final status = data['status'] as String? ?? 'active';
      if (status == 'suspended') {
        await _authService.logout();
        throw Exception(
            '\u062A\u0645 \u062A\u0639\u0644\u064A\u0642 \u062D\u0633\u0627\u0628\u0643. \u064A\u0631\u062C\u0649 \u0627\u0644\u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645.');
      }

      // Check 2: userSuspensions collection (source of truth).
      final suspensionDoc = await FirebaseFirestore.instance
          .collection('userSuspensions')
          .doc(userId)
          .get();
      if (suspensionDoc.exists && (suspensionDoc.data()?['isActive'] == true)) {
        await _authService.logout();
        throw Exception(
            '\u062A\u0645 \u062A\u0639\u0644\u064A\u0642 \u062D\u0633\u0627\u0628\u0643. \u064A\u0631\u062C\u0649 \u0627\u0644\u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645.');
      }

      await CacheService.saveUserId(userId);
      await CacheService.saveUserRole(data['role'] as String);
      await CacheService.saveUserName(data['name'] as String);

      // ✅ FIX: Ensure existing users have all UserModel fields initialized
      // This handles backward compatibility for users created before field additions
      await _ensureUserFields(userId, data);

      await _saveFCMTokenWithRetry();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? gender,
    String? honorific,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _ensureTeacherRegistrationAllowed(role);

      final cred = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user == null) throw Exception('فشل إنشاء الحساب');

      final userId = cred.user!.uid;

      try {
        // ✅ FIX 1: 'uid' is required by the Firestore security rule:
        //   request.resource.data.uid == userId
        // ✅ FIX 2: 'status' matches UserModel @Default('active')
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'uid': userId,
          'name': name,
          'email': email,
          'role': role,
          if (role == roleMohaffez && teacherHonorifics.contains(honorific))
            'honorific': honorific,
          'status': 'active',
          'photoUrl': null,
          'bio': null,
          'youtubeVideoUrl': null,
          'specialization': null,
          'phoneNumber': null,
          'followerCount': 0,
          'followingCount': 0,
          'rating': 0.0,
          'reviewCount': 0,
          if (role == roleMohaffez) ...{
            'ratingSum': 0.0,
            'ratingScale': 5,
            'ratingPolicyVersion': 2,
          },
          'addressText': null,
          'addressLat': null,
          'addressLng': null,
          'setupCompleted': false,
          'dateOfBirth': null,
          'city': null,
          'accountType': role == roleParent ? 'guardian' : 'individual',
          'activeStudentProfileId': role == roleParent ? null : 'self',
          'examScore': null,
          'examTakenAt': null,
          'examRetryCount': 0,
          'examPassed': false,
          'examNextRetryAt': null,
          'gender': gender,
          ..._initialCommissionFields(role),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // ✅ FIX 3: Delete the orphan Firebase Auth account if Firestore
        // write fails. Without this, the user can never re-register with
        // the same email because Auth already holds the account.
        try {
          await _authService.currentUser?.delete();
        } catch (_) {
          // Best-effort cleanup — ignore secondary error
        }
        rethrow;
      }

      await CacheService.saveUserId(userId);
      await CacheService.saveUserRole(role);
      await CacheService.saveUserName(name);

      await _saveFCMTokenWithRetry();
    });
  }

  /// Triggers the Google account picker and signs into Firebase.
  /// For existing users: completes sign-in normally.
  /// For new users (no Firestore doc): throws [NeedsRoleSelectionException]
  /// so the UI can collect role and gender, then call [completeGoogleSignIn].
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final cred = await _authService.signInWithGoogle();
      if (cred.user == null) throw Exception('فشل تسجيل الدخول');

      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final userId = cred.user!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        // New Google user — let UI collect role/gender first.
        throw NeedsRoleSelectionException(
          name: cred.user!.displayName ?? '',
          email: cred.user!.email ?? '',
          photoUrl: cred.user!.photoURL,
        );
      }

      final data = userDoc.data() as Map<String, dynamic>;

      final status = data['status'] as String? ?? 'active';
      if (status == 'suspended') {
        await _authService.logout();
        throw Exception('تم تعليق حسابك. يرجى التواصل مع الدعم.');
      }

      final suspensionDoc = await FirebaseFirestore.instance
          .collection('userSuspensions')
          .doc(userId)
          .get();
      if (suspensionDoc.exists && suspensionDoc.data()?['isActive'] == true) {
        await _authService.logout();
        throw Exception('تم تعليق حسابك. يرجى التواصل مع الدعم.');
      }

      await CacheService.saveUserId(userId);
      await CacheService.saveUserRole(data['role'] as String);
      await CacheService.saveUserName(data['name'] as String);
      await _ensureUserFields(userId, data);
      await _saveFCMTokenWithRetry();
    });
  }

  /// Called after the user selects role and gender for a new Google account.
  /// The Firebase Auth user is already signed in; this creates the Firestore doc.
  Future<void> completeGoogleSignIn({
    required String role,
    required String gender,
    String? honorific,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final user = _authService.currentUser;
      if (user == null) throw Exception('الجلسة انتهت، يرجى المحاولة مجدداً');

      await _ensureTeacherRegistrationAllowed(role);

      final userId = user.uid;
      final name = user.displayName ?? '';
      final email = user.email ?? '';
      final photoUrl = user.photoURL;

      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'uid': userId,
          'name': name,
          'email': email,
          'role': role,
          if (role == roleMohaffez && teacherHonorifics.contains(honorific))
            'honorific': honorific,
          'status': 'active',
          'photoUrl': photoUrl,
          'bio': null,
          'youtubeVideoUrl': null,
          'specialization': null,
          'phoneNumber': null,
          'followerCount': 0,
          'followingCount': 0,
          'rating': 0.0,
          'reviewCount': 0,
          if (role == roleMohaffez) ...{
            'ratingSum': 0.0,
            'ratingScale': 5,
            'ratingPolicyVersion': 2,
          },
          'addressText': null,
          'addressLat': null,
          'addressLng': null,
          'setupCompleted': false,
          'dateOfBirth': null,
          'city': null,
          'accountType': role == roleParent ? 'guardian' : 'individual',
          'activeStudentProfileId': role == roleParent ? null : 'self',
          'examScore': null,
          'examTakenAt': null,
          'examRetryCount': 0,
          'examPassed': false,
          'examNextRetryAt': null,
          'gender': gender,
          ..._initialCommissionFields(role),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        try {
          await _authService.logout();
        } catch (_) {}
        rethrow;
      }

      await CacheService.saveUserId(userId);
      await CacheService.saveUserRole(role);
      await CacheService.saveUserName(name);
      await _saveFCMTokenWithRetry();
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _authService.logout();
      // Reset booking flow provider on sign-out
      _ref.read(bookingFlowProvider.notifier).reset();
      await CacheService.clearAll();
      _ref.invalidate(authStateProvider);
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _authService.sendPasswordResetEmail(email);
    });

    if (!state.hasError) {
      state = const AsyncValue.data(null);
    }
  }

  Future<DocumentSnapshot> _waitForUserDoc(
    String userId, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) return doc;

      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    throw Exception('مستند المستخدم غير موجود بعد $maxRetries محاولات');
  }

  Future<void> _saveFCMTokenWithRetry() async {
    // NOTE: FCM token saving moved to mobile package
    // await NotificationService.saveFCMToken();
    // This is intentionally left as a no-op in core; mobile handles this after sign-in
  }

  /// Ensures existing users have all UserModel fields initialized.
  /// This handles backward compatibility when new fields are added to UserModel.
  Future<void> _ensureUserFields(
    String userId,
    Map<String, dynamic> existingData,
  ) async {
    final updates = <String, dynamic>{};

    // Define default values for all UserModel fields
    final fieldDefaults = <String, dynamic>{
      'bio': null,
      'youtubeVideoUrl': null,
      'specialization': null,
      'phoneNumber': null,
      'addressText': null,
      'addressLat': null,
      'addressLng': null,
      'setupCompleted': false,
      'dateOfBirth': null,
      'city': null,
      'accountType': 'individual',
      'examScore': null,
      'examTakenAt': null,
      'examRetryCount': 0,
      'examPassed': false,
      'examNextRetryAt': null,
    };

    // Check each field and add to updates if missing
    for (final entry in fieldDefaults.entries) {
      if (!existingData.containsKey(entry.key)) {
        updates[entry.key] = entry.value;
      }
    }
    final role = existingData['role']?.toString().trim().toLowerCase();
    if (!existingData.containsKey('activeStudentProfileId') &&
        role == roleStudent) {
      updates['activeStudentProfileId'] = 'self';
    }

    // Only update if there are missing fields
    if (updates.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update(updates);
        debugPrint(
            'AuthNotifier: Updated missing fields for user $userId: ${updates.keys.join(', ')}');
      } catch (e) {
        // Non-fatal: Log but don't block login
        debugPrint(
            'AuthNotifier: Failed to update user fields (non-fatal): $e');
      }
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> logout() => _auth.signOut();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('تم إلغاء تسجيل الدخول');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }
}

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

final currentAuthUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});
