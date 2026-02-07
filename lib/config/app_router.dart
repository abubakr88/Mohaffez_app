// FILE: lib/config/app_router.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/session_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/availability_management_screen.dart';
import '../screens/completed_sessions_screen.dart';
import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../screens/mohaffez_credentials_screen.dart';
import '../screens/mohaffez_home.dart';
import '../screens/mohaffez_profile_screen.dart';
import '../screens/mohaffez_students_screen.dart';
import '../screens/nearby_mohaffez_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/pending_requests_screen.dart';
import '../screens/privacy_settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/session_completion_screen.dart';
import '../screens/session_details_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/student_assignments_screen.dart';
import '../screens/student_home.dart';
import '../screens/student_requests_screen.dart';
import '../screens/upcoming_sessions_screen.dart';
import '../shared/constants/app_theme.dart';
import 'guard_manager.dart';
import '../screens/student_payment_screen.dart';
import '../screens/mohaffez_pricing_screen.dart';

// GoRouter Notifier for auth state changes
class GoRouterNotifier extends ChangeNotifier {
  final Ref ref;

  GoRouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (prev, next) {
      if (next.hasValue || next.hasError) {
        notifyListeners();
      }
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    return GuardManager.checkGuards(ref, state);
  }
}

// Main GoRouter Provider
final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: kDebugMode,
    redirectLimit: 12,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ============================================
      // PUBLIC ROUTES (No Shell)
      // ============================================
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

      // ============================================
      // AUTHENTICATED ROUTES (Wrapped in HomeShell)
      // ============================================
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          // ============================================
          // STUDENT ROUTES
          // ============================================
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
              final extra = state.extra;
              if (extra is! SessionModel) {
                return ErrorScreen(
                  error: 'بيانات الجلسة غير صحيحة',
                  onRetry: () => context.go('/'),
                );
              }
              return SessionDetailsScreen(session: extra);
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

          // ============================================
          // SHARED ROUTES (Both Student & Mohaffez)
          // ============================================
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
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/privacy-settings',
            name: 'privacy-settings',
            builder: (context, state) => const PrivacySettingsScreen(),
          ),
          GoRoute(
            path: '/payment/:mohaffezId',
            name: 'payment',
            builder: (context, state) {
              final mohaffezId = state.pathParameters['mohaffezId']!;
              final mohaffezName = state.uri.queryParameters['name'] ?? '';
              return StudentPaymentScreen(
                mohaffezId: mohaffezId,
                mohaffezName: mohaffezName,
              );
            },
          ),
          // ============================================
          // MOHAFFEZ ROUTES
          // ============================================
          GoRoute(
            path: '/mohaffez-home',
            name: 'mohaffez-home',
            builder: (context, state) => const MohaffezHome(),
          ),
          GoRoute(
            path: '/pending-requests',
            name: 'pending-requests',
            builder: (context, state) {
              final mohaffezId = state.uri.queryParameters['mohaffezId'];
              if (mohaffezId == null || mohaffezId.isEmpty) {
                return ErrorScreen(
                  error: 'معرف المحفظ مطلوب',
                  onRetry: () => context.go('/mohaffez-home'),
                );
              }
              return PendingRequestsScreen(mohaffezId: mohaffezId);
            },
          ),
          GoRoute(
            path: '/completed-sessions',
            name: 'completed-sessions',
            builder: (context, state) {
              final mohaffezId = state.uri.queryParameters['mohaffezId'];
              if (mohaffezId == null || mohaffezId.isEmpty) {
                return ErrorScreen(
                  error: 'معرف المحفظ مطلوب',
                  onRetry: () => context.go('/mohaffez-home'),
                );
              }
              return CompletedSessionsScreen(mohaffezId: mohaffezId);
            },
          ),
          GoRoute(
            path: '/upcoming-sessions',
            name: 'upcoming-sessions',
            builder: (context, state) {
              final mohaffezId = state.uri.queryParameters['mohaffezId'];
              if (mohaffezId == null || mohaffezId.isEmpty) {
                return ErrorScreen(
                  error: 'معرف المحفظ مطلوب',
                  onRetry: () => context.go('/mohaffez-home'),
                );
              }
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
          // ✅ MY STUDENTS ROUTE - FIXED
          GoRoute(
            path: '/my-students',
            name: 'my-students',
            builder: (context, state) => const MohaffezStudentsScreen(),
          ),
          GoRoute(
            path: '/complete-session/:sessionId',
            name: 'complete-session',
            builder: (context, state) {
              final sessionId = state.pathParameters['sessionId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return SessionCompletionScreen(
                sessionId: sessionId,
                studentName: extra?['studentName'] ?? '',
                previousHifz: extra?['previousHifz'],
                previousMuraja: extra?['previousMuraja'],
              );
            },
          ),
          GoRoute(
            path: '/pricing-management',
            name: 'pricing-management',
            builder: (context, state) => const MohaffezPricingScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error?.toString() ?? 'حدث خطأ',
      onRetry: () => context.go('/'),
    ),
  );
});

// ============================================
// SPLASH SCREEN
// ============================================
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const maxWaitDuration = Duration(seconds: 8);
  bool hasTimedOut = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    Future.delayed(maxWaitDuration, () {
      if (mounted) {
        setState(() {
          hasTimedOut = true;
          errorMessage = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
        });
      }
    });
  }

  void _retry() {
    setState(() {
      hasTimedOut = false;
      errorMessage = null;
    });
    _startTimeout();
    ref.invalidate(authStateProvider);
  }

  void _goToLogin() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    // Show error state if timed out
    if (hasTimedOut && authAsync.isLoading) {
      return _buildTimeoutScreen();
    }

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
              // Logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    size: 80,
                    color: AppTheme.primaryAmber,
                  ),
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
                'تطبيق تحفيظ القرآن الكريم',
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
              // Status Text
              Text(
                _getStatusText(authAsync),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeoutScreen() {
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
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                // Error Title
                const Text(
                  'مشكلة في الاتصال',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Error Message
                Text(
                  errorMessage ?? 'حدث خطأ في الاتصال',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Retry Button
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryAmber,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Go to Login Button
                    OutlinedButton.icon(
                      onPressed: _goToLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _getStatusText(AsyncValue authAsync) {
    if (authAsync.isLoading) return 'جاري التحميل...';
    if (authAsync.hasError) return 'حدث خطأ في تسجيل الدخول';
    if (authAsync.value == null) return 'جاري التحقق...';
    return 'مرحباً بك';
  }
}

// ============================================
// ERROR SCREEN
// ============================================
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
