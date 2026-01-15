// lib/config/route_guard.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Base interface for route guards
abstract class RouteGuard {
  /// Check if navigation should be redirected
  /// Returns redirect path if needed, null to allow navigation
  /// Changed from WidgetRef to Ref for compatibility with Provider callbacks
  String? check(Ref ref, GoRouterState state); // ✅ Changed here
  
  /// Priority (lower = checked first)
  int get priority => 100;
}
