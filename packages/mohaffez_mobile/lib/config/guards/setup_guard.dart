// lib/config/guards/setup_guard.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:go_router/go_router.dart';

import '../../tour/tour_mode_state.dart';
import '../route_guard.dart';

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
    '/teacher-certificates',
    '/teacher-pending',
    '/teacher-rejected',
    '/pick-location',
  };

  @override
  String? check(Ref ref, GoRouterState state) {
    // Tour mode: synthetic user already has setupCompleted: true.
    if (ref.read(tourModeProvider).active) return null;

    final authState = ref.read(authStateProvider);
    if (authState.value == null) return null; // not authenticated

    final AsyncValue<UserModel?> userState = ref.read(currentUserProvider);
    if (userState.isLoading || userState.hasError) return null;

    final user = userState.value;
    if (user == null) return null;

    // Skip setup check for admin users — they don't need onboarding.
    if (user.role == 'admin') return null;

    final currentPath = state.uri.path;

    // If user hasn't completed setup and isn't on an exempt route → redirect
    if (!user.setupCompleted && !exemptRoutes.contains(currentPath)) {
      // Mohaffez who already passed the exam should go to the certificates
      // step, not back to /setup (which would show the exam/profile form again).
      if (user.role == 'mohaffez' && user.examPassed) {
        return '/teacher-certificates';
      }
      return setupPath;
    }

    // If user IS on /setup but already completed → redirect to role home
    // (RoleGuard will handle pending_approval / rejected routing from there.)
    if (user.setupCompleted && currentPath == setupPath) {
      if (user.role == 'mohaffez') return '/mohaffez-home';
      return '/home';
    }

    return null;
  }
}
