// FILE: lib/config/app_router.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/session_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/suspension_provider.dart';
import '../providers/user_provider.dart';
import '../screens/availability_management_screen.dart';
import '../screens/completed_sessions_screen.dart';
import '../screens/commission_dashboard_screen.dart';
import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/mohaffez_commission_screen.dart';
import '../screens/mohaffez_credentials_screen.dart';
import '../screens/mohaffez_home.dart';
import '../screens/mohaffez_profile_screen.dart';
import '../screens/mohaffez_students_screen.dart';
import '../screens/mohaffez_wallet_settings_screen.dart';
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
import '../shared/theme/app_theme_constants.dart';
import '../shared/theme/theme_extensions.dart';
import 'guard_manager.dart';
import '../screens/student_payment_screen.dart';
import '../screens/mohaffez_pricing_screen.dart';
import '../screens/select_bundle_plan_screen.dart';
import '../screens/student_sessions_screen.dart';
import '../screens/student_schedule_screen.dart';
import '../screens/admin_home_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_user_detail_screen.dart';
import '../screens/admin_credentials_screen.dart';
import '../screens/admin_failed_operations_screen.dart';
import '../screens/admin_promo_codes_screen.dart';
import '../screens/admin_system_settings_screen.dart';
import '../screens/admin_dev_mode_screen.dart';
import '../screens/admin_broadcast_screen.dart';
import '../screens/admin_slot_locks_screen.dart';
import '../screens/admin_payment_events_screen.dart';
import '../screens/maintenance_screen.dart';
import '../screens/admin_audit_log_screen.dart';
import '../screens/admin_wallet_settings_screen.dart';
import '../screens/admin_teacher_commissions_screen.dart';
import '../screens/mohaffez_schedule_screen.dart'; // ← teacher calendar
import '../screens/suspended_screen.dart';
import '../screens/active_subscriptions_screen.dart'; // BUG-8: Active subscriptions screen
import '../screens/direct_payment_screen.dart'; // Path C: Direct payment route
import '../screens/booking_method_screen.dart'; // Booking method screen
import '../screens/confirm_bundle_session_screen.dart'; // Path A: Confirm bundle session
import '../screens/student/booking_confirmation_screen.dart'; // Booking confirmation
import '../providers/booking_flow_provider.dart';
import '../screens/direct_booking_request_screen.dart'; // Path C — Request First
import '../screens/select_bundle_plan_screen.dart';

// GoRouter Notifier for auth state changes
class GoRouterNotifier extends ChangeNotifier {
  final Ref ref;
  bool _scheduled = false;

  GoRouterNotifier(this.ref) {
    // Pre-warm suspension stream — MUST be first to ensure it is mounted
    // before any redirect fires, preventing ConcurrentModificationError.
    ref.listen(isUserSuspendedProvider, (_, __) => _scheduleNotify());

    // Pre-warm auth stream
    ref.listen(authStateProvider, (_, __) => _scheduleNotify());

    // Pre-warm current user — only notify once data or error is available
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (prev, next) {
      if (next.hasValue || next.hasError) {
        _scheduleNotify();
      }
    });
  }

  /// Coalesces multiple simultaneous provider fires into a single
  /// [notifyListeners] call per microtask cycle.
  /// This prevents the triple-redirect storm on sign-out and reduces
  /// App Check token request pressure.
  void _scheduleNotify() {
    if (_scheduled) return;
    _scheduled = true;
    Future.microtask(() {
      _scheduled = false;
      // Guard against notifying after disposal (e.g. hot-restart edge cases).
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        name: 'maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        // WHY: Keep lockout route outside HomeShell for a full-screen suspension state.
        path: '/suspended',
        name: 'suspended',
        builder: (context, state) => const SuspendedScreen(),
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
            path: '/my-sessions',
            name: 'my-sessions',
            builder: (context, state) => const StudentSessionsScreen(),
          ),
          GoRoute(
            path: '/my-schedule',
            name: 'my-schedule',
            builder: (context, state) => const StudentScheduleScreen(),
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
          // BOOKING ROUTES (All Paths)
          // ============================================
          GoRoute(
            path: '/booking/method',
            name: 'booking-method',
            builder: (context, state) => const BookingMethodScreen(),
          ),
          GoRoute(
            path: '/booking/select-bundle-plan',
            name: 'booking-select-bundle-plan',
            builder: (context, state) => const SelectBundlePlanScreen(),
          ),
                    GoRoute(
            path: '/booking/confirm-bundle-session',
            name: 'booking-confirm-bundle-session',
            builder: (context, state) => const ConfirmBundleSessionScreen(),
          ),
          GoRoute(
            path: '/booking/direct-payment',
            name: 'booking-direct-payment',
            builder: (context, state) => DirectPaymentScreen(),
          ),
          // ── Path C — Request First (direct payment, teacher must accept first) ──────
          GoRoute(
            path: '/booking/direct-request',
            name: 'booking-direct-request',
            builder: (context, state) => const DirectBookingRequestScreen(),
          ),

                    // ============================================
          // SHARED ROUTES (Both Student & Mohaffez)
          // ============================================
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          // BUG-8 FIX: Route for active subscriptions screen
          GoRoute(
            path: '/active-subscriptions',
            name: 'active-subscriptions',
            builder: (context, state) => const ActiveSubscriptionsScreen(),
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

          // ============================================
          // WALLET & COMMISSIONS
          // ============================================
          GoRoute(
            path: '/wallet-settings',
            name: 'wallet-settings',
            builder: (context, state) => const MohaffezWalletSettingsScreen(),
          ),
          GoRoute(
            path: '/mohaffez-commissions',
            name: 'mohaffez-commissions',
            builder: (context, state) {
              final uid = ref.read(currentUserIdProvider) ?? '';
              return MohaffezCommissionScreen(mohaffezId: uid);
            },
          ),
          GoRoute(
            path: '/payment/:mohaffezId',
            name: 'payment',
            builder: (context, state) {
              final mohaffezId = state.pathParameters['mohaffezId']!;
              final mohaffezName =
                  state.uri.queryParameters['name'] ?? '';
              final requestId = state.uri.queryParameters['requestId'];

              final extra = state.extra as Map<String, dynamic>?;
              final lockedRequest =
                  extra?['lockedRequest'] as Map<String, dynamic>?;

              final sessionType =
                  state.uri.queryParameters['sessionType'];
              final timeSlot = state.uri.queryParameters['timeSlot'];
              final sessionDateStr =
                  state.uri.queryParameters['sessionDate'];
              final location = state.uri.queryParameters['location'];
              final latStr = state.uri.queryParameters['lat'];
              final lngStr = state.uri.queryParameters['lng'];
              final phone = state.uri.queryParameters['phone'];

              Map<String, dynamic>? preselectedTimeSlot;
              if (timeSlot != null && timeSlot.contains('-')) {
                final parts = timeSlot.split('-');
                if (parts.length == 2) {
                  preselectedTimeSlot = {
                    'startTime': parts[0].trim(),
                    'endTime': parts[1].trim(),
                  };
                }
              }

              DateTime? preselectedDate;
              if (sessionDateStr != null && sessionDateStr.isNotEmpty) {
                preselectedDate = DateTime.tryParse(sessionDateStr);
              }

              double? lat;
              double? lng;
              if (latStr != null && latStr.isNotEmpty) {
                lat = double.tryParse(latStr);
              }
              if (lngStr != null && lngStr.isNotEmpty) {
                lng = double.tryParse(lngStr);
              }

              return StudentPaymentScreen(
                mohaffezId: mohaffezId,
                mohaffezName: mohaffezName,
                requestId: requestId,
                preselectedSessionType: sessionType,
                preselectedTimeSlot: preselectedTimeSlot,
                preselectedDate: preselectedDate,
                location: location,
                mohaffezAddress: location,
                mohaffezLat: lat,
                mohaffezLng: lng,
                mohaffezPhone: phone,
                lockedRequest: lockedRequest,
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
            builder: (context, state) => const PendingRequestsScreen(),
          ),
          GoRoute(
            path: '/completed-sessions',
            name: 'completed-sessions',
            builder: (context, state) {
              final mohaffezId =
                  state.uri.queryParameters['mohaffezId'];
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
              final mohaffezId =
                  state.uri.queryParameters['mohaffezId'];
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
            builder: (context, state) =>
                const AvailabilityManagementScreen(),
          ),
          GoRoute(
            path: '/my-students',
            name: 'my-students',
            builder: (context, state) => const MohaffezStudentsScreen(),
          ),
          GoRoute(
            path: 'mohaffez/students',
            redirect: (context, state) => '/my-students',
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

          // ── NEW: Teacher Calendar ──────────────────────────────────────
          GoRoute(
            path: '/teacher-schedule',
            name: 'teacher-schedule',
            builder: (context, state) => const MohaffezScheduleScreen(),
          ),
          // ──────────────────────────────────────────────────────────────

          // ============================================
          // ADMIN ROUTES
          // ============================================
          GoRoute(
            path: '/admin-home',
            name: 'admin-home',
            builder: (context, state) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            name: 'admin-users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/user-detail',
            name: 'admin-user-detail',
            builder: (context, state) {
              final user = state.extra as Map<String, dynamic>;
              return AdminUserDetailScreen(user: user);
            },
          ),
          GoRoute(
            path: '/admin/credentials',
            name: 'admin-credentials',
            builder: (context, state) => const AdminCredentialsScreen(),
          ),
          GoRoute(
            path: '/admin/failed-ops',
            name: 'admin-failed-ops',
            builder: (context, state) =>
                const AdminFailedOperationsScreen(),
          ),
          GoRoute(
            path: '/admin/promo-codes',
            name: 'admin-promo-codes',
            builder: (context, state) => const AdminPromoCodesScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            name: 'admin-settings',
            builder: (context, state) =>
                const AdminSystemSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/dev-mode',
            name: 'admin-dev-mode',
            builder: (context, state) => const AdminDevModeScreen(),
          ),
          GoRoute(
            path: '/admin/broadcast',
            name: 'admin-broadcast',
            builder: (context, state) => const AdminBroadcastScreen(),
          ),
          GoRoute(
            path: '/admin/slot-locks',
            name: 'admin-slot-locks',
            builder: (context, state) => const AdminSlotLocksScreen(),
          ),
          GoRoute(
            path: '/admin/payment-events',
            name: 'admin-payment-events',
            builder: (context, state) =>
                const AdminPaymentEventsScreen(),
          ),
          GoRoute(
            path: '/admin/commissions',
            name: 'admin-commissions',
            builder: (context, state) =>
                const CommissionDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/teacher-commissions',
            name: 'admin-teacher-commissions',
            builder: (context, state) =>
                const AdminTeacherCommissionsScreen(),
          ),
          GoRoute(
            path: '/admin/wallet-numbers',
            name: 'admin-wallet-numbers',
            builder: (context, state) =>
                const AdminWalletSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/audit-log',
            name: 'admin-audit-log',
            builder: (context, state) => const AdminAuditLogScreen(),
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

    if (hasTimedOut && authAsync.isLoading) {
      return _buildTimeoutScreen();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppThemeConstants.primaryAmber,
              AppThemeConstants.primaryAmberLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(AppThemeConstants.spaceLg),
                decoration: BoxDecoration(
                  color: AppThemeConstants.surfaceWhite,
                  borderRadius: AppThemeConstants.borderRadiusXl,
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
                  width: AppThemeConstants.icon3xl,
                  height: AppThemeConstants.icon3xl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    size: AppThemeConstants.icon3xl,
                    color: AppThemeConstants.primaryAmber,
                  ),
                ),
              ),
              Spacing.vXl,
              Text(
                'محفظ',
                style: context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.surfaceWhite,
                ),
              ),
              Spacing.vMd,
              Text(
                'تطبيق تحفيظ القرآن الكريم',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppThemeConstants.surfaceWhite
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppThemeConstants.space2xl),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeConstants.surfaceWhite),
                strokeWidth: 3,
              ),
              Spacing.vMd,
              Text(
                _getStatusText(authAsync),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppThemeConstants.surfaceWhite
                      .withValues(alpha: 0.7),
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
            colors: [
              AppThemeConstants.primaryAmber,
              AppThemeConstants.primaryAmberLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(AppThemeConstants.spaceXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(
                      AppThemeConstants.spaceLg),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.surfaceWhite,
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
                    size: AppThemeConstants.icon2xl,
                    color: AppThemeConstants.warning,
                  ),
                ),
                Spacing.vXl,
                Text(
                  'مشكلة في الاتصال',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.surfaceWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                Spacing.vMd,
                Text(
                  errorMessage ?? 'حدث خطأ في الاتصال',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: AppThemeConstants.surfaceWhite
                        .withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: AppThemeConstants.spaceXl +
                      AppThemeConstants.spaceSm,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppThemeConstants.surfaceWhite,
                        foregroundColor:
                            AppThemeConstants.primaryAmber,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeConstants.spaceLg,
                          vertical: AppThemeConstants.spaceMd,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              AppThemeConstants.borderRadiusMd,
                        ),
                      ),
                    ),
                    Spacing.hMd,
                    OutlinedButton.icon(
                      onPressed: _goToLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            AppThemeConstants.surfaceWhite,
                        side: const BorderSide(
                          color: AppThemeConstants.surfaceWhite,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeConstants.spaceLg,
                          vertical: AppThemeConstants.spaceMd,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              AppThemeConstants.borderRadiusMd,
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
            padding:
                const EdgeInsets.all(AppThemeConstants.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: AppThemeConstants.icon2xl,
                  color: AppThemeConstants.error,
                ),
                Spacing.vMd,
                Text(
                  'حدث خطأ',
                  style: context.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Spacing.vSm,
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppThemeConstants.spaceXl,
                      vertical: AppThemeConstants.spaceMd,
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
