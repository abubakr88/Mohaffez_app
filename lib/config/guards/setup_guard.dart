// lib/config/guards/setup_guard.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_guard.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Redirects users who haven't completed account setup to /setup.
/// Priority 15 — runs AFTER AuthGuard (10), BEFORE RoleGuard (20).
class SetupGuard implements RouteGuard {
  @override
  int get priority => 15;

  static const String setupPath = '/setup';

  /// Routes that should NOT trigger the setup redirect.
  static const Set<String> exemptRoutes = {
    '/',
    '/login',
    '/register',
    '/maintenance',
    '/suspended',
    '/exam-result',
    setupPath,
  };

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    if (authState.value == null) return null; // not authenticated

    final AsyncValue<UserModel?> userState = ref.read(currentUserProvider);
    if (userState.isLoading || userState.hasError) return null;

    final user = userState.value;
    if (user == null) return null;

    // Skip setup check for admin users — they don't need onboarding.
    if (user.role == 'admin') return null;

    final currentPath = state.uri.path;

    // Backward compatibility: existing users created before feature deployment
    // do NOT have setupCompleted in their doc. UserModel defaults it to false,
    // which would force them into setup. Grandfather them by checking createdAt.
    // TODO: Remove this after running the Firestore migration script.
    if (!user.setupCompleted && user.createdAt != null) {
      final cutoffDate = DateTime(2026, 3, 23); // deployment date — adjust
      if (user.createdAt!.isBefore(cutoffDate)) {
        return null; // grandfather existing users
      }
    }

    // If user hasn't completed setup and isn't on an exempt route → redirect
    if (!user.setupCompleted && !exemptRoutes.contains(currentPath)) {
      return setupPath;
    }

    // If user IS on /setup but already completed → redirect to role home
    if (user.setupCompleted && currentPath == setupPath) {
      if (user.role == 'mohaffez') return '/mohaffez-home';
      return '/home';
    }

    return null;
  }
}
