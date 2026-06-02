// FILE: lib/config/app_router.dart
import 'package:flutter/foundation.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Shared screens
import '../screens/shared/home_shell.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/register_screen.dart';
import '../screens/shared/google_role_selection_screen.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/shared/maintenance_screen.dart';
import '../screens/shared/suspended_screen.dart';
import '../screens/shared/setup_account_screen.dart';
import '../screens/shared/exam_result_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/student/student_rewards_screen.dart';
import '../screens/shared/settings_screen.dart';
import '../screens/shared/location_settings_screen.dart';
import '../screens/shared/privacy_settings_screen.dart';
import '../screens/shared/cancellation_policy_screen.dart';
import '../screens/shared/payment_webview_screen.dart';
import '../screens/shared/pick_location_screen.dart';
import '../screens/shared/session_details_screen.dart';
// Student screens
import '../screens/student/student_home.dart';
import '../screens/student/student_assignments_screen.dart';
import '../screens/student/student_requests_screen.dart';
import '../screens/student/student_sessions_screen.dart';
import '../screens/student/student_schedule_screen.dart';
import '../screens/student/student_payment_screen.dart';
import '../screens/student/nearby_mohaffez_screen.dart';
import '../screens/student/mohaffez_profile_screen.dart';
import '../screens/student/rate_session_screen.dart';
import '../screens/student/booking_method_screen.dart';
import '../screens/student/select_bundle_plan_screen.dart';
import '../screens/student/confirm_bundle_session_screen.dart';
import '../screens/student/direct_booking_request_screen.dart';
import '../screens/student/direct_payment_screen.dart';
import '../screens/student/active_subscriptions_screen.dart';
import '../screens/student/student_wallet_screen.dart';
import '../screens/student/wallet_topup_screen.dart';
// Teacher screens
import '../screens/teacher/mohaffez_home.dart';
import '../screens/teacher/mohaffez_credentials_screen.dart';
import '../screens/teacher/mohaffez_pricing_screen.dart';
import '../screens/teacher/mohaffez_schedule_screen.dart';
import '../screens/teacher/mohaffez_students_screen.dart';
import '../screens/teacher/mohaffez_student_detail_screen.dart';
import '../screens/teacher/mohaffez_wallet_settings_screen.dart';
import '../screens/teacher/mohaffez_wallet_screen.dart';
import '../screens/teacher/request_payout_screen.dart';
import '../screens/teacher/availability_management_screen.dart';
import '../screens/teacher/pending_requests_screen.dart';
import '../screens/teacher/direct_payment_confirmations_screen.dart';
import '../screens/teacher/completed_sessions_screen.dart';
import '../screens/teacher/upcoming_sessions_screen.dart';
import '../screens/teacher/session_quiz_screen.dart';
import '../screens/teacher/student_challenges_screen.dart';
import '../screens/teacher/session_completion_screen.dart';
import '../screens/teacher/teacher_certificates_screen.dart';
import '../screens/teacher/teacher_pending_screen.dart';
import '../screens/teacher/teacher_rejected_screen.dart';
import '../screens/teacher/teacher_setup_wizard_screen.dart';
// Admin: removed from the consumer mobile app for security — administration now
// lives only on the web console. Admins who sign in see a "use web" notice.
import '../screens/shared/admin_web_only_screen.dart';
import '../shared/widgets/interactive_quran_page.dart';
import '../shared/theme/theme_extensions.dart';
import 'guard_manager.dart';

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
        path: '/google-role-selection',
        name: 'google-role-selection',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return GoogleRoleSelectionScreen(
            name: extra['name'] as String,
            email: extra['email'] as String,
            photoUrl: extra['photoUrl'] as String?,
          );
        },
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
      // ── Admin: web-only notice (admin UI removed from mobile for security).
      // Kept outside HomeShell so admins get a clean full-screen notice + logout,
      // with no admin chrome/bottom-nav. RoleGuard still routes admins here.
      GoRoute(
        path: '/admin-home',
        name: 'admin-home',
        builder: (context, state) => const AdminWebOnlyScreen(),
      ),
      // ── One-time account setup (outside HomeShell — no bottom nav) ──
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (context, state) => const SetupAccountScreen(),
      ),
      // ── Exam result screen ──
      GoRoute(
        path: '/exam-result',
        name: 'exam-result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ExamResultScreen(
            score: extra?['score'] ?? 0.0,
            correctAnswers: extra?['correctAnswers'] ?? 0,
            totalQuestions: extra?['totalQuestions'] ?? 0,
          );
        },
      ),
      // ── Teacher registration flow (outside HomeShell — no bottom nav) ──
      GoRoute(
        path: '/teacher-certificates',
        name: 'teacher-certificates',
        builder: (context, state) => const TeacherCertificatesScreen(),
      ),
      GoRoute(
        path: '/teacher-pending',
        name: 'teacher-pending',
        builder: (context, state) => const TeacherPendingScreen(),
      ),
      GoRoute(
        path: '/teacher-rejected',
        name: 'teacher-rejected',
        builder: (context, state) => const TeacherRejectedScreen(),
      ),

      // ============================================
      // AUTHENTICATED ROUTES (Wrapped in HomeShell)
      // ============================================
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          // WHY: Wizard is inside ShellRoute so context.push() to step screens
          // stays within the same navigator, avoiding duplicate page-key crashes.
          // HomeShell hides its chrome (appBar/drawer/bottomNav) on this route.
          GoRoute(
            path: '/teacher-setup-wizard',
            name: 'teacher-setup-wizard',
            builder: (context, state) => const TeacherSetupWizardScreen(),
          ),
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
            path: '/student-wallet',
            name: 'student-wallet',
            builder: (context, state) => const StudentWalletScreen(),
          ),
          GoRoute(
            path: '/wallet-topup',
            name: 'wallet-topup',
            builder: (context, state) => const WalletTopupScreen(),
          ),
          GoRoute(
            path: '/rate-session/:sessionId',
            name: 'rate-session',
            builder: (context, state) {
              final sessionId = state.pathParameters['sessionId'] ?? '';
              final mohaffezName = state.uri.queryParameters['mohaffezName'] ?? 'المحفظ';
              return RateSessionScreen(
                sessionId: sessionId,
                mohaffezName: mohaffezName,
              );
            },
          ),
          GoRoute(
            path: '/mushaf/:pageNumber',
            name: 'mushaf-viewer',
            builder: (context, state) {
              final pageNumber = int.tryParse(state.pathParameters['pageNumber'] ?? '') ?? 1;
              final extra = state.extra as Map<String, dynamic>?;
              final mistakes = extra?['mistakes'] as List<QuranMistake>?;
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('مراجعة الأخطاء'),
                    backgroundColor: AppThemeConstants.primary,
                  ),
                  body: InteractiveQuranPage(
                    pageNumber: pageNumber,
                    existingMistakes: mistakes ?? [],
                    onMistakeAdded: (_) {}, // read-only no-op
                    isEditable: false,
                  ),
                ),
              );
            },
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
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return DirectPaymentScreen(
                requestId: extra?['requestId'],
                mohaffezId: extra?['mohaffezId'],
                mohaffezName: extra?['mohaffezName'],
                studentName: extra?['studentName'],
                studentEmail: extra?['studentEmail'] ?? '',
                studentPhone: extra?['studentPhone'] ?? '',
                amount: extra?['amount'],
                sessionType: extra?['sessionType'],
                preferredTimeSlot: extra?['preferredTimeSlot'],
                slotDate: extra?['slotDate'],
                slotStart: extra?['slotStart'],
                slotEnd: extra?['slotEnd'],
                imamAddressText: extra?['imamAddressText'],
                imamAddressLat: extra?['imamAddressLat'],
                imamAddressLng: extra?['imamAddressLng'],
                mohaffezPhone: extra?['mohaffezPhone'],
                planType: extra?['planType'],
                planId: extra?['planId'],
                planTitle: extra?['planTitle'],
                sessionsCount: extra?['sessionsCount'],
                validityDays: extra?['validityDays'],
                autoBookFirstSession: extra?['autoBookFirstSession'] ?? false,
              );
            },
          ),
          GoRoute(
            path: '/payment-webview',
            name: 'payment-webview',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return PaymentWebViewScreen(
                paymentUrl: extra?['paymentUrl'] ?? '',
                paymentId: extra?['paymentId'] ?? '',
                plan: extra?['plan'] as PricingPlanModel,
              );
            },
          ),
          GoRoute(
            path: '/pick-location',
            name: 'pick-location',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return PickLocationScreen(
                initialLat: extra?['initialLat'],
                initialLng: extra?['initialLng'],
                initialSearchQuery: extra?['initialSearchQuery'],
              );
            },
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
            path: '/student-rewards',
            name: 'student-rewards',
            builder: (context, state) => const StudentRewardsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/location-settings',
            name: 'location-settings',
            builder: (context, state) => const LocationSettingsScreen(),
          ),
          GoRoute(
            path: '/privacy-settings',
            name: 'privacy-settings',
            builder: (context, state) => const PrivacySettingsScreen(),
          ),
          GoRoute(
            path: '/cancellation-policy',
            name: 'cancellation-policy',
            builder: (context, state) => const CancellationPolicyScreen(),
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
            path: '/mohaffez-wallet',
            name: 'mohaffez-wallet',
            builder: (context, state) => const MohaffezWalletScreen(),
          ),
          GoRoute(
            path: '/request-payout',
            name: 'request-payout',
            builder: (context, state) => const RequestPayoutScreen(),
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
            path: '/mohaffez/requests/confirm',
            name: 'mohaffez-confirm-payment',
            builder: (context, state) {
              final directPaymentRequestId =
                  state.uri.queryParameters['directPaymentRequestId'];
              return DirectPaymentConfirmationsScreen(
                directPaymentRequestId: directPaymentRequestId,
              );
            },
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
              final filterParam = state.uri.queryParameters['filter'];
              final initialFilter = filterParam == 'today'
                  ? UpcomingFilter.today
                  : filterParam == 'thisWeek'
                      ? UpcomingFilter.thisWeek
                      : filterParam == 'thisMonth'
                          ? UpcomingFilter.thisMonth
                          : UpcomingFilter.all;
              return UpcomingSessionsScreen(
                mohaffezId: mohaffezId,
                initialFilter: initialFilter,
              );
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
            path: '/student/:studentId',
            name: 'student-detail',
            builder: (context, state) {
              final mohaffezId = ref.read(currentUserIdProvider) ?? '';
              final student = state.extra as MohaffezStudentSummary?;

              if (student == null) {
                return ErrorScreen(
                  error: 'بيانات الطالب غير موجودة',
                  onRetry: () => context.go('/my-students'),
                );
              }

              return MohaffezStudentDetailScreen(
                student: student,
                mohaffezId: mohaffezId,
              );
            },
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
                previousHifzFromAyah: extra?['previousHifzFromAyah'] as String?,
                previousHifzToAyah: extra?['previousHifzToAyah'] as String?,
                previousMurajaFromAyah: extra?['previousMurajaFromAyah'] as String?,
                previousMurajaToAyah: extra?['previousMurajaToAyah'] as String?,
                isLateCompletion: extra?['isLateCompletion'] == true,
                sessionType: extra?['sessionType'] as String?,
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
          GoRoute(
            path: '/session-quiz',
            name: 'session-quiz',
            builder: (context, state) {
              final p = state.uri.queryParameters;
              return SessionQuizScreen(
                studentName: p['studentName'],
                mohaffezId: p['mohaffezId'],
                studentId: p['studentId'],
                sessionId: p['sessionId'],
              );
            },
          ),
          GoRoute(
            path: '/student-challenges',
            name: 'student-challenges',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return StudentChallengesScreen(
                mohaffezId: extra['mohaffezId'] as String,
                studentId: extra['studentId'] as String,
                studentName: extra['studentName'] as String,
              );
            },
          ),
          // ──────────────────────────────────────────────────────────────

          // Admin routes were removed from the mobile app (web console only).
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
