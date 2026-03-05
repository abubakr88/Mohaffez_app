// FILE: lib/config/guards/role_guard.dart
// CHANGES:
// - Made types explicit (AsyncValue<UserModel?>) for better null-safety/readability.
// - Improved route matching: checks by path prefix, plus explicit shared routes bypass.
// - Added defensive handling for unknown/empty roles.
// - Avoided redirects while user doc is still loading (TimeoutGuard will handle hard timeouts).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_guard.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';

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
    '/session', // session details
  ];

  // Mohaffez-only routes.
  static const List<String> mohaffezRoutePrefixes = <String>[
    '/mohaffez-home',
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

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final AsyncValue<UserModel?> userState = ref.read(currentUserProvider);
    final config = ref.read(systemConfigProvider).valueOrNull;
    final currentPath = state.uri.path;

    // Only process if authenticated (AuthGuard handles unauth).
    if (authState.value == null) return null;

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

      final destination = _homeForRole(user.role);
      if (destination == null) return loginPath; // defensive: unknown role
      return destination;
    }

    // Protected routes: if user still loading, don't redirect yet.
    if (userState.isLoading) return null;

    // If error, let UI handle (and TimeoutGuard may resolve on splash).
    if (userState.hasError) return null;

    final user = userState.value;
    if (user == null) return null;

    final role = user.role.trim();
    if (role.isEmpty) return loginPath;

    if (config != null &&
        config.maintenanceMode == true &&
        !config.maintenanceAllowedUids.contains(user.uid) &&
        currentPath != '/maintenance') {
      return '/maintenance';
    }

    // Enforce role-based access.
    if (_startsWithAny(currentPath, mohaffezRoutePrefixes) &&
        role != 'mohaffez') {
      return studentHomePath;
    }

    if (_startsWithAny(currentPath, studentRoutePrefixes) &&
        role == 'mohaffez') {
      return mohaffezHomePath;
    }

    if (_startsWithAny(currentPath, adminRoutePrefixes) && role != 'admin') {
      return studentHomePath;
    }

    return null;
  }

  static bool _startsWithAny(String path, List<String> prefixes) {
    return prefixes.any((p) => path == p || path.startsWith('$p/'));
  }

  static String? _homeForRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'admin') return adminHomePath;
    if (normalized == 'mohaffez') return mohaffezHomePath;
    if (normalized == 'student') return studentHomePath;
    return null;
  }
}
