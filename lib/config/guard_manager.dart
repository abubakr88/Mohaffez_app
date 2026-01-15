// lib/config/guard_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_guard.dart';
import 'guards/timeout_guard.dart';
import 'guards/auth_guard.dart';
import 'guards/role_guard.dart';

/// Manages and executes route guards in priority order
class GuardManager {
  static final List<RouteGuard> _guards = [
    TimeoutGuard(),
    AuthGuard(),
    RoleGuard(),
  ]..sort((a, b) => a.priority.compareTo(b.priority));
  
  /// Execute all guards and return first redirect result
  /// Changed from WidgetRef to Ref to work with Provider callbacks
  static String? checkGuards(Ref ref, GoRouterState state) { // ✅ Changed here
    debugPrint('🔍 GuardManager: Checking route ${state.matchedLocation}');
    
    for (final guard in _guards) {
      final result = guard.check(ref, state);
      
      if (result != null) {
        debugPrint('🔀 ${guard.runtimeType}: Redirecting to $result');
        return result;
      }
    }
    
    debugPrint('✅ GuardManager: Access granted to ${state.matchedLocation}');
    return null; // Allow navigation
  }
  
  /// Add custom guard (useful for feature-specific guards)
  static void addGuard(RouteGuard guard) {
    _guards.add(guard);
    _guards.sort((a, b) => a.priority.compareTo(b.priority));
  }
  
  /// Remove guard
  static void removeGuard(Type guardType) {
    _guards.removeWhere((g) => g.runtimeType == guardType);
  }
}
