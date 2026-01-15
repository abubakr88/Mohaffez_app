// lib/config/app_router.dart (REFACTORED - COMPLETE FILE)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/student_home.dart';
import '../screens/mohaffez_home.dart';
import '../screens/nearby_mohaffez_screen.dart';
import '../screens/mohaffez_profile_screen.dart';
import '../screens/session_details_screen.dart';
import '../screens/student_assignments_screen.dart';
import '../screens/student_requests_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/pending_requests_screen.dart';
import '../screens/completed_sessions_screen.dart';
import '../screens/upcoming_sessions_screen.dart';
import '../screens/mohaffez_credentials_screen.dart';
import '../screens/availability_management_screen.dart';
import '../models/session_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart'; // ✅ ADD THIS IMPORT
import 'guard_manager.dart';
import '../shared/constants/app_theme.dart';

// ============================================================================
// GoRouter Notifier (FIXED)
// ============================================================================

class GoRouterNotifier extends ChangeNotifier {
  final Ref ref;

  GoRouterNotifier(this.ref) {
    // Listen to auth state changes
    ref.listen(authStateProvider, (_, next) {
      debugPrint('🔄 GoRouterNotifier: Auth state changed');
      notifyListeners();
    });
    
    // ✅ FIXED: Listen to user data changes with proper null handling
    ref.listen<AsyncValue>(currentUserProvider, (previous, next) { // ✅ Added type annotation
      // Only notify on data changes, not loading states
      if (next.hasValue || next.hasError) {
        debugPrint('🔄 GoRouterNotifier: User data updated (hasValue: ${next.hasValue}, hasError: ${next.hasError})');
        notifyListeners();
      }
    });
  }

  /// Simplified redirect - delegates to GuardManager
  String? redirect(BuildContext context, GoRouterState state) {
    return GuardManager.checkGuards(ref, state);
  }
}

// ============================================================================
// Router Provider (UNCHANGED)
// ============================================================================

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);
  
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // PUBLIC ROUTES
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // AUTHENTICATED ROUTES - STUDENT
      GoRoute(
        path: '/home',
        name: 'student-home',
        builder: (context, state) => const StudentHome(),
      ),
      GoRoute(
        path: '/nearby',
        name: 'nearby',
        builder: (context, state) => const NearbyMohaffezScreen(),
      ),
      GoRoute(
        path: '/mohaffez/:id',
        name: 'mohaffez-profile',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final lat = state.uri.queryParameters['lat'];
          final lng = state.uri.queryParameters['lng'];
          return MohaffezProfileScreen(
            mohaffezId: id,
            userLat: lat != null ? double.tryParse(lat) : null,
            userLng: lng != null ? double.tryParse(lng) : null,
          );
        },
      ),
      GoRoute(
        path: '/session/:id',
        name: 'session-details',
        builder: (context, state) {
          final sessionData = state.extra as SessionModel;
          return SessionDetailsScreen(session: sessionData);
        },
      ),
      GoRoute(
        path: '/assignments',
        name: 'assignments',
        builder: (context, state) => const StudentAssignmentsScreen(),
      ),
      GoRoute(
        path: '/requests',
        name: 'requests',
        builder: (context, state) => const StudentRequestsScreen(),
      ),
      
      // SHARED ROUTES (Both roles)
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      
      // AUTHENTICATED ROUTES - MOHAFFEZ
      GoRoute(
        path: '/mohaffez-home',
        name: 'mohaffez-home',
        builder: (context, state) => const MohaffezHome(),
      ),
      GoRoute(
        path: '/pending-requests',
        name: 'pending-requests',
        builder: (context, state) {
          final mohaffezId = state.uri.queryParameters['mohaffezId']!;
          return PendingRequestsScreen(mohaffezId: mohaffezId);
        },
      ),
      GoRoute(
        path: '/completed-sessions',
        name: 'completed-sessions',
        builder: (context, state) {
          final mohaffezId = state.uri.queryParameters['mohaffezId']!;
          return CompletedSessionsScreen(mohaffezId: mohaffezId);
        },
      ),
      GoRoute(
        path: '/upcoming-sessions',
        name: 'upcoming-sessions',
        builder: (context, state) {
          final mohaffezId = state.uri.queryParameters['mohaffezId']!;
          return UpcomingSessionsScreen(mohaffezId: mohaffezId);
        },
      ),
      GoRoute(
        path: '/credentials',
        name: 'credentials',
        builder: (context, state) => const MohaffezCredentialsScreen(),
      ),
      GoRoute(
        path: '/availability',
        name: 'availability',
        builder: (context, state) => const AvailabilityManagementScreen(),
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error?.toString() ?? 'خطأ غير معروف',
      onRetry: () => context.go('/'),
    ),
  );
});

// ============================================================================
// Splash Screen (SIMPLIFIED)
// ============================================================================

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers to trigger rebuilds (guards handle all logic)
    final authAsync = ref.watch(authStateProvider);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.school,
                      size: 80,
                      color: AppTheme.primaryAmber,
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              
              // App Title
              const Text(
                'محفظ',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'تطبيق حفظ القرآن الكريم',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 50),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              
              // Status Text (simplified)
              Text(
                _getStatusText(authAsync),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(AsyncValue authAsync) {
    if (authAsync.isLoading) return 'جاري التحقق من الحساب...';
    if (authAsync.hasError) return 'خطأ في المصادقة';
    if (authAsync.value == null) return 'جاري الانتقال لتسجيل الدخول...';
    return 'جاري تحميل البيانات...';
  }
}

// ============================================================================
// Error Screen (UNCHANGED)
// ============================================================================

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
