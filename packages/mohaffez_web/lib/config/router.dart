import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dev/component_gallery_page.dart';

// Student pages
import '../features/student/dashboard/student_dashboard_page.dart';
import '../features/student/sessions/student_sessions_page.dart';
import '../features/student/subscriptions/student_subscriptions_page.dart';
import '../features/student/rewards/student_rewards_page.dart';
import '../features/student/profile/student_profile_page.dart';
import '../features/student/teachers/student_teachers_page.dart';
import '../features/student/assignments/student_assignments_page.dart';

// Teacher pages
import '../features/teacher/dashboard/teacher_dashboard_page.dart';
import '../features/teacher/students/teacher_students_page.dart';
import '../features/teacher/sessions/teacher_sessions_page.dart';
import '../features/teacher/pricing/teacher_pricing_page.dart';
import '../features/teacher/certificates/teacher_certificates_page.dart';
import '../features/teacher/schedule/teacher_schedule_page.dart';
import '../features/teacher/earnings/teacher_earnings_page.dart';
import '../features/teacher/profile/teacher_profile_page.dart';

// Admin pages
import '../features/admin/dashboard/admin_dashboard_page.dart';
import '../features/admin/users/admin_users_page.dart';
import '../features/admin/approvals/admin_approvals_page.dart';
import '../features/admin/sessions/admin_sessions_page.dart';
import '../features/admin/payments/admin_payments_page.dart';
import '../features/admin/promos/admin_promos_page.dart';
import '../features/admin/config/admin_config_page.dart';
import '../features/admin/reports/admin_reports_page.dart';

// Shells
import '../shell/student_shell.dart';
import '../shell/teacher_shell.dart';
import '../shell/admin_shell.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth     = _ref.read(authProvider);
    final location = state.uri.toString();
    final isLogin  = location == '/login';

    if (auth.step == AuthStep.loading) return null;

    if (!auth.isAuthenticated) {
      return isLogin ? null : '/login';
    }

    if (isLogin) {
      return switch (auth.role) {
        'mohaffez' => '/t',
        'admin'    => '/admin',
        _          => '/s',
      };
    }

    final role = auth.role;
    if (role == 'student' && (location.startsWith('/t') || location.startsWith('/admin'))) return '/s';
    if (role == 'mohaffez' && (location.startsWith('/s') || location.startsWith('/admin'))) return '/t';
    if (role == 'admin' && (location.startsWith('/s') || location.startsWith('/t'))) return '/admin';

    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final webRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login',          builder: (_, __) => const LoginPage()),
      GoRoute(path: '/dev/components', builder: (_, __) => const ComponentGalleryPage()),

      // ── Student shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          GoRoute(path: '/s',               builder: (_, __) => const StudentDashboardPage()),
          GoRoute(path: '/s/teachers',      builder: (_, __) => const StudentTeachersPage()),
          GoRoute(path: '/s/sessions',      builder: (_, __) => const StudentSessionsPage()),
          GoRoute(path: '/s/assignments',   builder: (_, __) => const StudentAssignmentsPage()),
          GoRoute(path: '/s/subscriptions', builder: (_, __) => const StudentSubscriptionsPage()),
          GoRoute(path: '/s/rewards',       builder: (_, __) => const StudentRewardsPage()),
          GoRoute(path: '/s/profile',       builder: (_, __) => const StudentProfilePage()),
        ],
      ),

      // ── Teacher shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => TeacherShell(child: child),
        routes: [
          GoRoute(path: '/t',               builder: (_, __) => const TeacherDashboardPage()),
          GoRoute(path: '/t/students',      builder: (_, __) => const TeacherStudentsPage()),
          GoRoute(path: '/t/schedule',      builder: (_, __) => const TeacherSchedulePage()),
          GoRoute(path: '/t/sessions',      builder: (_, __) => const TeacherSessionsPage()),
          GoRoute(path: '/t/pricing',       builder: (_, __) => const TeacherPricingPage()),
          GoRoute(path: '/t/certificates',  builder: (_, __) => const TeacherCertificatesPage()),
          GoRoute(path: '/t/earnings',      builder: (_, __) => const TeacherEarningsPage()),
          GoRoute(path: '/t/profile',       builder: (_, __) => const TeacherProfilePage()),
        ],
      ),

      // ── Admin shell ───────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin',           builder: (_, __) => const AdminDashboardPage()),
          GoRoute(path: '/admin/users',     builder: (_, __) => const AdminUsersPage()),
          GoRoute(path: '/admin/approvals', builder: (_, __) => const AdminApprovalsPage()),
          GoRoute(path: '/admin/sessions',  builder: (_, __) => const AdminSessionsPage()),
          GoRoute(path: '/admin/payments',  builder: (_, __) => const AdminPaymentsPage()),
          GoRoute(path: '/admin/promos',    builder: (_, __) => const AdminPromosPage()),
          GoRoute(path: '/admin/config',    builder: (_, __) => const AdminConfigPage()),
          GoRoute(path: '/admin/reports',   builder: (_, __) => const AdminReportsPage()),
        ],
      ),
    ],
  );
});
