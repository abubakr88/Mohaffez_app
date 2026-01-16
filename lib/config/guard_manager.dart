// FILE: lib/config/guard_manager.dart
// CHANGES:
// - Added loop protection: if a guard returns a redirect identical to the current URI (path+query), ignore it.
// - Added small helper to compare redirect target with current location safely.
// - Reduced noisy logs (kept logs but made them conditional in debug mode).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_guard.dart';
import 'guards/timeout_guard.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

/// Manages and executes route guards in priority order.
class GuardManager {
  static final List<RouteGuard> _guards = <RouteGuard>[
    TimeoutGuard(),
    AuthGuard(),
    RoleGuard(),
  ]..sort((a, b) => a.priority.compareTo(b.priority));

  /// Execute all guards and return first redirect result.
  static String? checkGuards(Ref ref, GoRouterState state) {
    final current = state.uri;

    if (kDebugMode) {
      debugPrint('🔍 GuardManager: checking ${current.path}${_query(current)}');
    }

    for (final guard in _guards) {
      final redirect = guard.check(ref, state);

      if (redirect == null) continue;

      // ✅ Loop protection: don’t redirect to the same place (path+query).
      if (_isSameDestination(current, redirect)) {
        if (kDebugMode) {
          debugPrint(
            '♻️ GuardManager: ignoring redirect from ${guard.runtimeType} '
            'because it matches current location ($redirect)',
          );
        }
        continue;
      }

      if (kDebugMode) {
        debugPrint('🔀 ${guard.runtimeType}: redirect -> $redirect');
      }
      return redirect;
    }

    return null; // Allow navigation.
  }

  static bool _isSameDestination(Uri current, String redirectLocation) {
    final target = Uri.tryParse(redirectLocation);
    if (target == null) return false;

    // Compare both path and query for correctness.
    return target.path == current.path && target.query == current.query;
  }

  static String _query(Uri uri) => uri.hasQuery ? '?${uri.query}' : '';

  /// Add custom guard (feature-specific).
  static void addGuard(RouteGuard guard) {
    _guards.add(guard);
    _guards.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Remove guard.
  static void removeGuard(Type guardType) {
    _guards.removeWhere((g) => g.runtimeType == guardType);
  }
}
