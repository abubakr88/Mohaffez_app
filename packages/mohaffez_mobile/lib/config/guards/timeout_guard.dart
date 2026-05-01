// FILE: lib/config/guards/timeout_guard.dart
// CHANGES:
// - Replaced fragile “single static start time” with a safer state machine:
//   - Debounces repeated redirects while GoRouter is still resolving.
//   - Ensures logout is triggered at most once per splash cycle.
//   - Resets cleanly when leaving splash.
// - Avoided running logout in tight loops (prevents infinite redirects).
// - Kept behavior: only monitors "/" (splash) and only enforces after maxWaitDuration.
// - Arabic user-facing messages are not shown here (guard layer remains UI-free).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_guard.dart';
import 'package:mohaffez_core/src/providers/auth_provider.dart';
import 'package:mohaffez_core/src/providers/user_provider.dart';

/// Prevents infinite loading by enforcing timeouts (splash only).
class TimeoutGuard implements RouteGuard {
  @override
  int get priority => 5;

  static const Duration maxWaitDuration = Duration(seconds: 12);

  // FIX-TIMEOUT-1: Increase debounce to outlast GoRouter's default transition.
  static const Duration _redirectDebounce = Duration(milliseconds: 1500);

  static DateTime? _startedAt;
  static bool _logoutTriggered = false;

  static String? _lastRedirectLocation;
  static DateTime? _lastRedirectAt;

  @override
  String? check(Ref ref, GoRouterState state) {
    final currentPath = state.uri.path;

    // Only monitor splash.
    if (currentPath != '/') {
      _reset();
      return null;
    }

    _startedAt ??= DateTime.now();
    final elapsed = DateTime.now().difference(_startedAt!);

    final authState = ref.read(authStateProvider);
    final userState = ref.read(currentUserProvider);

    if (kDebugMode) {
      debugPrint(
        '⏱️ TimeoutGuard: ${elapsed.inSeconds}s | '
        'auth: ${_fmtAsync(authState)} | user: ${_fmtAsync(userState)}',
      );
    }

    // If auth already resolved to "no user", do not keep user on splash.
    if (!authState.isLoading && authState.value == null) {
      return _redirectOnce('/login');
    }

    // If authenticated and user loaded successfully, allow and reset.
    if (authState.value != null && userState.hasValue && userState.value != null) {
      _reset();
      return null;
    }

    // Timeout exceeded: decide action.
    if (elapsed >= maxWaitDuration) {
      if (kDebugMode) {
        debugPrint('⚠️ TimeoutGuard: timeout exceeded (${elapsed.inSeconds}s)');
      }

      // If still not authenticated -> go login (no logout needed).
      if (authState.value == null) {
        return _redirectOnce('/login');
      }

      // Authenticated but user doc is missing/error/loading too long -> logout once and go login.
      _triggerLogoutOnce(ref);

      return _redirectOnce('/login');
    }

    return null;
  }

  static void _triggerLogoutOnce(Ref ref) {
    if (_logoutTriggered) return;
    _logoutTriggered = true;

    // Fire-and-forget; guard must stay synchronous.
    Future.microtask(() async {
      try {
        await ref.read(authServiceProvider).logout();
      } catch (e) {
        // Swallow here to avoid breaking router; UI/services handle detailed reporting.
        if (kDebugMode) debugPrint('❌ TimeoutGuard logout failed: $e');
      }
    });
  }

  static String? _redirectOnce(String location) {
    final now = DateTime.now();
    final lastAt = _lastRedirectAt;

    if (_lastRedirectLocation == location && lastAt != null) {
      final since = now.difference(lastAt);
      if (since < _redirectDebounce) {
        return null; // debounce repeated redirects
      }
    }

    _lastRedirectLocation = location;
    _lastRedirectAt = now;
    return location;
  }

  static void _reset() {
    _startedAt = null;
    _logoutTriggered = false;
    _lastRedirectLocation = null;
    _lastRedirectAt = null;
  }

  static String _fmtAsync(AsyncValue<dynamic> v) {
    if (v.isLoading) return 'loading';
    if (v.hasError) return 'error';
    return v.value == null ? 'null' : 'data';
  }
}
