// lib/config/guards/timeout_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../route_guard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Prevents infinite loading by enforcing timeouts
class TimeoutGuard implements RouteGuard {
  @override
  int get priority => 5; // Check before other guards

  static DateTime? _firstLoadTime;
  static const maxWaitDuration = Duration(seconds: 12); // Increased from 8

  @override
  String? check(Ref ref, GoRouterState state) {
    final authState = ref.read(authStateProvider);
    final userState = ref.read(currentUserProvider);
    final currentPath = state.matchedLocation;

    // Only monitor splash screen
    if (currentPath != '/') {
      if (_firstLoadTime != null) {
        debugPrint("⏱️ TimeoutGuard: Left splash, resetting timer");
        _firstLoadTime = null;
      }
      return null;
    }

    // Start timer on first check
    if (_firstLoadTime == null) {
      _firstLoadTime = DateTime.now();
      debugPrint("⏱️ TimeoutGuard: Started timer");
    }

    final elapsed = DateTime.now().difference(_firstLoadTime!);

    // Log current state
    debugPrint("⏱️ TimeoutGuard: ${elapsed.inSeconds}s elapsed | "
        "Auth: ${authState.isLoading ? 'loading' : authState.value != null ? 'yes' : 'no'} | "
        "User: ${userState.isLoading ? 'loading' : userState.value != null ? 'yes' : 'no'}");

    // ✅ FIX 1: If auth finished loading and no user -> redirect immediately
    if (!authState.isLoading && authState.value == null && !userState.isLoading) {
      debugPrint("❌ TimeoutGuard: No auth detected -> /login");
      _firstLoadTime = null;
      return '/login';
    }

    // ✅ FIX 2: If we have auth but user data has permission error -> show it but don't logout
    if (authState.value != null && userState.hasError && !userState.isLoading) {
      final error = userState.error.toString();
      
      if (error.contains('PERMISSION_DENIED')) {
        debugPrint("🚫 TimeoutGuard: Permission denied error detected");
        
        // Only logout if this persists for more than 8 seconds
        if (elapsed.inSeconds >= 8) {
          debugPrint("❌ TimeoutGuard: Permission denied for ${elapsed.inSeconds}s -> logout");
          _firstLoadTime = null;
          Future.microtask(() {
            ref.read(authServiceProvider).logout();
          });
          return '/login';
        }
        
        // Still within grace period - let it retry
        debugPrint("⏳ TimeoutGuard: Waiting for permission issue to resolve...");
        return null;
      }

      // For other errors, check if user document doesn't exist
      if (error.contains('not exist') || error.contains('NOT_FOUND')) {
        debugPrint("❌ TimeoutGuard: User document doesn't exist -> logout");
        _firstLoadTime = null;
        Future.microtask(() {
          ref.read(authServiceProvider).logout();
        });
        return '/login';
      }

      // Other errors - wait a bit longer
      if (elapsed.inSeconds >= 10) {
        debugPrint("❌ TimeoutGuard: User error after ${elapsed.inSeconds}s -> logout");
        _firstLoadTime = null;
        Future.microtask(() {
          ref.read(authServiceProvider).logout();
        });
        return '/login';
      }
    }

    // ✅ FIX 3: Timeout exceeded - force action
    if (elapsed > maxWaitDuration) {
      debugPrint("⚠️ TimeoutGuard: TIMEOUT EXCEEDED (${elapsed.inSeconds}s)");
      _firstLoadTime = null;

      // If still loading anything - force to login
      if (authState.isLoading || userState.isLoading) {
        debugPrint("❌ TimeoutGuard: Still loading after timeout -> /login");
        return '/login';
      }

      // If not authenticated - go to login
      if (authState.value == null) {
        debugPrint("❌ TimeoutGuard: No auth after timeout -> /login");
        return '/login';
      }

      // Authenticated but no user data - force logout
      if (userState.value == null && !userState.hasError) {
        debugPrint("❌ TimeoutGuard: No user data after timeout -> logout");
        Future.microtask(() {
          ref.read(authServiceProvider).logout();
        });
        return '/login';
      }
    }

    return null; // Continue to other guards
  }
}
