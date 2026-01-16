// FILE: lib/config/guards/auth_guard.dart
// CHANGES:
// - Fixed “stuck on splash until timeout”: when auth is resolved and user is unauthenticated, redirect from "/" -> "/login" immediately.
// - Added extra loop protection: never redirect if already at "/login".
// - Improved handling for auth errors: unauthenticated experience remains consistent (go to login).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_guard.dart';
import '../../providers/auth_provider.dart';

/// Ensures user is authenticated.
class AuthGuard implements RouteGuard {
  @override
  int get priority => 10;

  static const String splashPath = '/';
  static const String loginPath = '/login';

  // Public routes that don't require authentication.
  static const Set<String> publicRoutes = {splashPath, loginPath};

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final currentPath = state.uri.path;
    final isPublicRoute = publicRoutes.contains(currentPath);

    // Still loading auth state -> do nothing.
    if (authState.isLoading) return null;

    // Auth error -> force user to login screen (don’t get stuck).
    if (authState.hasError) {
      if (currentPath == loginPath) return null;
      return loginPath;
    }

    final isAuthenticated = authState.value != null;

    // ✅ Critical fix: unauthenticated users should not stay on splash.
    if (!isAuthenticated && currentPath == splashPath) {
      return loginPath;
    }

    // Not authenticated -> redirect to login (unless already on a public route).
    if (!isAuthenticated && !isPublicRoute) {
      return loginPath;
    }

    return null;
  }
}
