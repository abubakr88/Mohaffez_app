// lib/config/guards/role_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../route_guard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Redirects authenticated users from splash/login and enforces role-based access
class RoleGuard implements RouteGuard {
  @override
  int get priority => 20; // Check after AuthGuard and TimeoutGuard

  // Routes accessible to any authenticated user
  static const sharedRoutes = ['notifications', 'profile', 'session'];

  // Mohaffez-only routes
  static const mohaffezRoutes = [
    'mohaffez-home',
    'pending-requests',
    'completed-sessions',
    'upcoming-sessions',
    'credentials',
    'availability',
  ];

  // Student-only routes
  static const studentRoutes = [
    'home',
    'nearby',
    'assignments',
    'requests',
    'mohaffez',
  ];

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final userState = ref.read(currentUserProvider);
    final currentPath = state.matchedLocation;

    // ✅ Only process if authenticated
    if (authState.value == null) {
      debugPrint("🔄 RoleGuard: No auth, skipping");
      return null; // Let AuthGuard handle
    }

    debugPrint("🔄 RoleGuard: Auth exists, checking user data...");

    // ✅ On splash or login with auth - redirect based on user data
    if (currentPath == '/' || currentPath == '/login') {
      // Still loading user data - wait
      if (userState.isLoading) {
        debugPrint("🔄 RoleGuard: User loading, waiting...");
        return null;
      }

      // ✅ NEW: Handle permission errors gracefully
      if (userState.hasError) {
        final error = userState.error.toString();
        
        if (error.contains('PERMISSION_DENIED')) {
          debugPrint("⚠️ RoleGuard: Permission error on splash/login");
          // Don't redirect yet - let TimeoutGuard handle after proper timeout
          return null;
        }

        if (error.contains('not exist') || error.contains('NOT_FOUND')) {
          debugPrint("❌ RoleGuard: User document doesn't exist");
          // This is a real error - user needs to logout
          return null; // Let TimeoutGuard handle logout
        }

        // Other errors - wait a bit
        debugPrint("⚠️ RoleGuard: User error, waiting...");
        return null;
      }

      // User data loaded - redirect to home
      if (userState.value != null) {
        final role = userState.value!.role;
        final destination = role == 'mohaffez' ? '/mohaffez-home' : '/home';
        debugPrint("✅ RoleGuard: Redirecting $role to $destination");
        return destination;
      }

      // No user data but no error either - still loading
      debugPrint("⏳ RoleGuard: Auth but no user yet, waiting...");
      return null;
    }

    // ✅ For protected routes, ensure user data is loaded
    if (userState.isLoading) {
      debugPrint("🔄 RoleGuard: User loading on protected route, waiting...");
      return null;
    }

    // ✅ Handle errors on protected routes
    if (userState.hasError) {
      final error = userState.error.toString();
      
      if (error.contains('PERMISSION_DENIED')) {
        debugPrint("⚠️ RoleGuard: Permission error on protected route");
        // Allow navigation - don't block user
        // Show error in UI instead
        return null;
      }

      // For other errors, let TimeoutGuard handle
      debugPrint("⚠️ RoleGuard: User error on protected route");
      return null;
    }

    // No user data on protected route - let TimeoutGuard handle
    if (userState.value == null) {
      debugPrint("⚠️ RoleGuard: No user on protected route");
      return null; // Let TimeoutGuard decide after timeout
    }

    // ✅ Check role-based access
    final role = userState.value!.role;

    if (_isMohaffezRoute(currentPath) && role != 'mohaffez') {
      debugPrint("🚫 RoleGuard: Student blocked from mohaffez route");
      return '/home';
    }

    if (_isStudentRoute(currentPath) && role == 'mohaffez') {
      debugPrint("🚫 RoleGuard: Mohaffez blocked from student route");
      return '/mohaffez-home';
    }

    debugPrint("✅ RoleGuard: Access granted to $currentPath for $role");
    return null;
  }

  bool _isMohaffezRoute(String path) {
    return mohaffezRoutes.any((route) => path.startsWith('/$route'));
  }

  bool _isStudentRoute(String path) {
    return studentRoutes.any((route) => path.startsWith('/$route'));
  }
}
