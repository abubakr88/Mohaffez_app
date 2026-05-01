// lib/screens/teacher_pending_screen.dart
//
// Shown after the teacher submits registration for approval.
// Watches the user's status field in real-time:
//   'pending_approval' → stays here
//   'active'           → admin approved  → push to /mohaffez-home
//   'rejected'         → admin rejected  → push to /teacher-rejected

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mohaffez_core/src/providers/auth_provider.dart';
import 'package:mohaffez_core/src/providers/user_provider.dart';
import 'package:mohaffez_core/src/theme/app_theme_constants.dart';

class TeacherPendingScreen extends ConsumerWidget {
  const TeacherPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    // WHY: Navigation on status change is handled exclusively by RoleGuard
    // (triggered by GoRouterNotifier). An imperative context.go() here would
    // race with GoRouter's own redirect and cause a duplicate page-key crash.

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7F6),
            body: userAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
              data: (user) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: Column(
                    children: [
                      // ── Illustration ────────────────────────────
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE67E22)
                                  .withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.hourglass_top_rounded,
                            size: 60, color: Color(0xFFE67E22)),
                      ),
                      const SizedBox(height: 32),

                      // ── Title ───────────────────────────────────
                      const Text(
                        'طلبك قيد المراجعة',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'شكراً لتسجيلك في منصة المحفظ.\n'
                        'سيقوم فريق الإدارة بمراجعة بياناتك وشهاداتك '
                        'والرد عليك خلال 24-48 ساعة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4B5563),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Status card ─────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppThemeConstants.white,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(
                              color: const Color(0xFFE5EDE9)),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeConstants.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            _StatusRow(
                              icon: Icons.check_circle_rounded,
                              color: Color(0xFF2E8B57),
                              label: 'تسجيل الحساب',
                              done: true,
                            ),
                            _Divider(),
                            _StatusRow(
                              icon: Icons.check_circle_rounded,
                              color: Color(0xFF2E8B57),
                              label: 'اجتياز الاختبار',
                              done: true,
                            ),
                            _Divider(),
                            _StatusRow(
                              icon: Icons.check_circle_rounded,
                              color: Color(0xFF2E8B57),
                              label: 'رفع الشهادات والملف المهني',
                              done: true,
                            ),
                            _Divider(),
                            _StatusRow(
                              icon: Icons.hourglass_top_rounded,
                              color: Color(0xFFE67E22),
                              label: 'مراجعة الطلب من الإدارة',
                              done: false,
                              isActive: true,
                            ),
                            _Divider(),
                            _StatusRow(
                              icon: Icons.lock_outline_rounded,
                              color: Color(0xFF9CA3AF),
                              label: 'تفعيل الحساب',
                              done: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Refresh hint ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF6F3),
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notifications_active_rounded,
                                size: 18, color: Color(0xFF0E8278)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ستتلقى إشعاراً فور اتخاذ قرار بشأن طلبك.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF095752),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Logout ──────────────────────────────────
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(authNotifierProvider.notifier).logout(),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('تسجيل الخروج'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppThemeConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool done;
  final bool isActive;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.done,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF111827)
                    : done
                        ? const Color(0xFF4B5563)
                        : const Color(0xFF9CA3AF),
              ),
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius:
                    const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                    color: const Color(0xFFE67E22)
                        .withValues(alpha: 0.4)),
              ),
              child: const Text('جارٍ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE67E22))),
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFE5EDE9));
}
