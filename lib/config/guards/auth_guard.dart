// lib/config/guards/auth_guard.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../route_guard.dart';
import '../../providers/auth_provider.dart';

/// Ensures user is authenticated
class AuthGuard implements RouteGuard {
  @override
  int get priority => 10; // Check first
  
  // Public routes that don't require authentication
  static const publicRoutes = {'/', '/login'};
  
  @override
  String? check(Ref ref, GoRouterState state) { // ✅ Changed here
    final authState = ref.read(authStateProvider);
    final currentPath = state.matchedLocation;
    final isPublicRoute = publicRoutes.contains(currentPath);
    
    // Still loading auth state
    if (authState.isLoading) {
      return null; // Wait for auth to resolve
    }
    
    // Auth error - force logout
    if (authState.hasError) {
      if (!isPublicRoute) {
        return '/login';
      }
      return null;
    }
    
    final isAuthenticated = authState.value != null;
    
    // Not authenticated - redirect to login (unless already on public route)
    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }
    
    // Authenticated user on public route - will be handled by RoleGuard
    return null;
  }
}
