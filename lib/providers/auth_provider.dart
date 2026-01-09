import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cache_service.dart';

// Auth state provider - watches Firebase auth changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Authentication notifier for sign in/sign up operations
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
      // Sign in with Firebase
      final cred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Load user data and cache it
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        await CacheService.saveUserId(cred.user!.uid);
        await CacheService.saveUserRole(data['role'] as String);
        await CacheService.saveUserName(data['name'] as String);
      }

      // Invalidate user provider to refresh
      _ref.invalidate(authStateProvider);
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
      // Create user with Firebase
      final cred = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'name': name,
        'email': email,
        'role': role,
        'photoUrl': null,
        'followerCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cache user data
      await CacheService.saveUserId(cred.user!.uid);
      await CacheService.saveUserRole(role);
      await CacheService.saveUserName(name);

      // Invalidate user provider to refresh
      _ref.invalidate(authStateProvider);
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _authService.logout();
      await CacheService.clearAll();
      
      // Invalidate all providers
      _ref.invalidate(authStateProvider);
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _authService.sendPasswordResetEmail(email);
    });
  }
}

// Auth notifier provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});

// Auth service class
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;
}

// Convenience providers for auth state checks
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value != null;
});

final currentAuthUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value;
});
