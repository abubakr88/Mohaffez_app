// FILE: lib/config/route_guard.dart
// CHANGES:
// - Kept API stable (Ref + GoRouterState), but tightened documentation.
// - Added a default `priority` and clarified contract (must return absolute paths like "/login").
// - Marked intent: guards must be pure + fast (no async work).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Base interface for route guards.
///
/// Contract:
/// - Return a redirect location (absolute path starting with "/") to block navigation.
/// - Return null to allow navigation.
/// - Must be synchronous and fast (no network/Firestore calls here).
abstract class RouteGuard {
  /// Check if navigation should be redirected.
  String? check(Ref ref, GoRouterState state);

  /// Priority (lower = checked first).
  int get priority => 100;
}
