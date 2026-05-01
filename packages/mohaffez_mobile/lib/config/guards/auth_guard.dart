// FILE: lib/config/guards/auth_guard.dart
// CHANGES:
// - Fixed stuck on splash when auth is resolved but user is unauthenticated
// - Added loop protection (never redirect if already at login)
// - Improved auth error handling
// - [FIX] Orphan account detection: authenticated + no Firestore doc → redirect to login

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_guard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class AuthGuard implements RouteGuard {
  @override
  int get priority => 10;

  static const String splashPath = '/';
  static const String loginPath = '/login';

  static const Set<String> publicRoutes = {
    splashPath,
    loginPath,
    '/register',
    '/maintenance',
  };

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final currentPath = state.uri.path;
    final isPublicRoute = publicRoutes.contains(currentPath);

    // Still loading auth — do nothing
    if (authState.isLoading) return null;

    // Auth error — force to login, don't get stuck
    if (authState.hasError) {
      if (currentPath == loginPath) return null;
      return loginPath;
    }

    final isAuthenticated = authState.value != null;

    // Unauthenticated on splash → go to login immediately
    if (!isAuthenticated && currentPath == splashPath) return loginPath;

    // Unauthenticated on protected route → go to login
    if (!isAuthenticated && !isPublicRoute) return loginPath;

    // ✅ FIX: Orphan account detection.
    // State: Firebase Auth session EXISTS but Firestore user doc is MISSING.
    // Cause: previous signUp() created Auth account then failed writing to Firestore.
    // Fix: redirect to login — LoginScreen will auto sign-out the orphan session.
    if (isAuthenticated) {
      final userState = ref.read(currentUserProvider);
      final isUserDocMissing = userState.hasValue && userState.value == null;

      if (isUserDocMissing && currentPath == splashPath) {
        if (kDebugMode) {
          debugPrint(
            'AuthGuard: Orphan account detected (Auth exists, Firestore doc missing). '
            'Redirecting to login for cleanup.',
          );
        }
        return loginPath;
      }
    }

    return null;
  }
}
