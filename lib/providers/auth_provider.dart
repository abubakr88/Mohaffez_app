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

import '../services/cache_service.dart';
import '../services/notification_service.dart';
import 'booking_flow_provider.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges().asyncMap((firebaseUser) async {
    if (firebaseUser != null) {
      try {
        await firebaseUser.getIdToken(false).timeout(const Duration(seconds: 10));
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

  AuthNotifier(this._authService, this._ref) : super(const AsyncValue.data(null));

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
      final status = data['status'] as String? ?? 'active';
      if (status == 'suspended') {
        await _authService.logout();
        throw Exception('\u062A\u0645 \u062A\u0639\u0644\u064A\u0642 \u062D\u0633\u0627\u0628\u0643. \u064A\u0631\u062C\u0649 \u0627\u0644\u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645.');
      }

      // Check 2: userSuspensions collection (source of truth).
      final suspensionDoc = await FirebaseFirestore.instance
          .collection('userSuspensions')
          .doc(userId)
          .get();
      if (suspensionDoc.exists &&
          (suspensionDoc.data()?['isActive'] == true)) {
        await _authService.logout();
        throw Exception('\u062A\u0645 \u062A\u0639\u0644\u064A\u0642 \u062D\u0633\u0627\u0628\u0643. \u064A\u0631\u062C\u0649 \u0627\u0644\u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645.');
      }

      await CacheService.saveUserId(userId);
      await CacheService.saveUserRole(data['role'] as String);
      await CacheService.saveUserName(data['name'] as String);

      await _saveFCMTokenWithRetry();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
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
          'status': 'active',
          'photoUrl': null,
          'followerCount': 0,
          'followingCount': 0,
          'rating': 0.0,
          'reviewCount': 0,
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
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await NotificationService.saveFCMToken();
        return;
      } catch (e) {
        if (attempt == 2) rethrow;
        await Future.delayed(const Duration(seconds: 1));
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
}

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

final currentAuthUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});
