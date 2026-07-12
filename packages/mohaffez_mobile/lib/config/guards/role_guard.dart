// FILE: lib/config/guards/role_guard.dart
// CHANGES:
// - Made types explicit (AsyncValue<UserModel?>) for better null-safety/readability.
// - Improved route matching: checks by path prefix, plus explicit shared routes bypass.
// - Added defensive handling for unknown/empty roles.
// - Avoided redirects while user doc is still loading (TimeoutGuard will handle hard timeouts).

import 'package:flutter/foundation.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../tour/tour_mode_state.dart';
import '../route_guard.dart';

/// Redirects authenticated users from splash/login and enforces role-based access.
class RoleGuard implements RouteGuard {
  @override
  int get priority => 20;

  static const String splashPath = '/';
  static const String loginPath = '/login';

  static const String studentHomePath = '/home';
  static const String mohaffezHomePath = '/mohaffez-home';
  static const String adminHomePath = '/admin-home';

  // Routes accessible to any authenticated user.
  static const List<String> sharedRoutePrefixes = <String>[
    '/notifications',
    '/profile',
    '/student-rewards',
    '/session', // session details
    '/mohaffez/requests',
    '/trial-requests',
  ];

  static const List<String> teacherRegistrationRoutePrefixes = <String>[
    '/teacher-certificates',
    '/teacher-pending',
    '/teacher-rejected',
  ];

  // Mohaffez-only routes.
  static const List<String> mohaffezRoutePrefixes = <String>[
    '/mohaffez-home',
    '/teacher-profile-preview',
    '/pending-requests',
    '/completed-sessions',
    '/upcoming-sessions',
    '/credentials',
    '/availability',
    '/wallet-settings',
  ];

  // Student-only routes.
  static const List<String> studentRoutePrefixes = <String>[
    '/home',
    '/nearby',
    '/assignments',
    '/requests',
    '/mohaffez', // profiles
  ];

  static const List<String> adminRoutePrefixes = <String>[
    '/admin-home',
    '/admin',
  ];

  static bool _isPublicRoute(String path) {
    return path.startsWith('/p/t/');
  }

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final AsyncValue<UserModel?> userState = ref.read(currentUserProvider);
    final config = ref.read(systemConfigProvider).valueOrNull;
    final currentPath = state.uri.path;
    final inTour = ref.read(tourModeProvider).active;

    if (_isPublicRoute(currentPath)) return null;

    // Only process if authenticated (AuthGuard handles unauth).
    // Tour mode supplies a synthetic user via overrides — treat as authenticated.
    if (authState.value == null &&
        !inTour &&
        !_startsWithAny(currentPath, teacherRegistrationRoutePrefixes)) {
      return null;
    }

    if (_startsWithAny(currentPath, teacherRegistrationRoutePrefixes)) {
      if (authState.isLoading) return splashPath;
      if (authState.value == null && !inTour) return loginPath;
      if (userState.isLoading || userState.hasError) return splashPath;

      final user = userState.value;
      if (user == null) return loginPath;

      final role = user.role.trim().toLowerCase();
      final status = user.status.trim().toLowerCase();

      if (role != roleMohaffez) {
        return _homeForUser(role, status) ?? studentHomePath;
      }

      if (status == 'active' &&
          (currentPath == '/teacher-pending' ||
              currentPath == '/teacher-rejected')) {
        return mohaffezHomePath;
      }
      if (status == 'pending_approval' && currentPath != '/teacher-pending') {
        return '/teacher-pending';
      }
      if (status == 'rejected' && currentPath != '/teacher-rejected') {
        return '/teacher-rejected';
      }
      return null;
    }

    // Shared routes are always allowed for authenticated users.
    if (_startsWithAny(currentPath, sharedRoutePrefixes)) return null;

    // On splash/login with auth: route based on role once user is available.
    if (currentPath == splashPath || currentPath == loginPath) {
      if (userState.isLoading) return null;

      // If user doc errored, wait: TimeoutGuard decides what to do.
      if (userState.hasError) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ RoleGuard: user load error on $currentPath: ${userState.error}');
        }
        return null;
      }

      final user = userState.value;
      if (user == null) return null;

      final destination = _homeForUser(user.role, user.status);
      if (destination == null) return loginPath; // defensive: unknown role
      return destination;
    }

    // Protected routes: if user still loading, don't redirect yet.
    if (userState.isLoading) return null;

    // If error, let UI handle (and TimeoutGuard may resolve on splash).
    if (userState.hasError) return null;

    final user = userState.value;

    // In tour mode the nested ProviderScope overrides are invisible to the
    // outer ref used by GoRouter. Derive the role directly from tourModeProvider
    // so role-based redirects still apply to demo users.
    String role;
    if (user == null) {
      if (!inTour) return null;
      final tourRole = ref.read(tourModeProvider).role;
      role = tourRole == TourRole.mohaffez ? roleMohaffez : roleStudent;
    } else {
      role = normalizeRole(user.role);
    }
    if (role.isEmpty) return loginPath;

    if (config != null &&
        config.maintenanceMode == true &&
        !config.maintenanceAllowedUids.contains(user?.uid) &&
        currentPath != '/maintenance') {
      return '/maintenance';
    }

    // Enforce role-based access.
    if (_startsWithAny(currentPath, mohaffezRoutePrefixes) &&
        role != roleMohaffez) {
      return studentHomePath;
    }

    if (_startsWithAny(currentPath, studentRoutePrefixes) &&
        role == roleMohaffez) {
      return mohaffezHomePath;
    }

    if (_startsWithAny(currentPath, adminRoutePrefixes) && role != roleAdmin) {
      return studentHomePath;
    }

    return null;
  }

  static bool _startsWithAny(String path, List<String> prefixes) {
    return prefixes.any((p) => path == p || path.startsWith('$p/'));
  }

  static String? _homeForUser(String role, String status) {
    final normalized = role.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();
    if (normalized == roleAdmin) return adminHomePath;
    if (isLearnerAccountRole(normalized)) return studentHomePath;
    if (normalized == roleMohaffez) {
      if (normalizedStatus == 'pending_approval') return '/teacher-pending';
      if (normalizedStatus == 'rejected') return '/teacher-rejected';
      return mohaffezHomePath;
    }
    return null;
  }
}
