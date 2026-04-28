// lib/screens/home_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider_paginated.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/teacher_setup_provider.dart';
import '../../models/user_model.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/utils/arabic_labels.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SHELL DESIGN TOKENS — keep in sync with mohaffez_home.dart _DS
// ═══════════════════════════════════════════════════════════════════════════════
class _ShellDS {
  // Teal brand (teacher / mohaffez)
  static const teal800 = Color(0xFF095752);
  static const teal600 = Color(0xFF0E8278);
  static const teal500 = Color(0xFF1A9E84);

  // Student / Admin use the original amber palette
  static const amberLight= Color(0xFFF5A623);

  // Neutral
  static const white70 = Color(0xB3FFFFFF);
  static const white40 = Color(0x66FFFFFF);
  static const white15 = Color(0x26FFFFFF);

  // Bottom nav background (shared)
// teal for mohaffez
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME SHELL
// ═══════════════════════════════════════════════════════════════════════════════
class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري التحميل...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppThemeConstants.error),
                const SizedBox(height: 16),
                const Text('حدث خطأ في تحميل البيانات'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.invalidate(currentUserProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final currentIndex    = ref.watch(bottomNavIndexProvider);
        final isMohaffez      = user.role == 'mohaffez';
        final isAdmin         = user.role == 'admin';
        final isDevModeActive = ref.watch(isDevModeActiveProvider);

        final unreadCount = ref
            .watch(unreadNotificationsCountProvider(user.uid))
            .value ?? 0;

        // WHY: wizard is inside the ShellRoute to avoid cross-navigator push
        // crashes, but it must appear full-screen (no chrome).
        final currentPath = GoRouterState.of(context).uri.path;
        final isWizard = currentPath == '/teacher-setup-wizard';

        // Sequential setup wizard flow: teacher tapped "دليل الإعداد السريع"
        // from the drawer and is walking through the 5 setup screens in order.
        const wizardStepRoutes = [
          '/profile',
          '/credentials',
          '/availability',
          '/wallet-settings',
          '/pricing-management',
        ];
        final wizardMode = ref.watch(wizardModeProvider);
        final isInWizardFlow = isMohaffez &&
            wizardMode &&
            wizardStepRoutes.contains(currentPath);
        final wizardStepIdx =
            isInWizardFlow ? wizardStepRoutes.indexOf(currentPath) : -1;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7F6),
            appBar: isWizard ? null : _buildAppBar(
              context, ref,
              isMohaffez: isMohaffez,
              isAdmin: isAdmin,
              currentIndex: currentIndex,
              userId: user.uid,
              unreadCount: unreadCount,
            ),
            drawer: (isWizard || isInWizardFlow) ? null : _buildDrawer(
              context, ref,
              isMohaffez: isMohaffez,
              isAdmin: isAdmin,
              isDevModeActive: isDevModeActive,
              user: user,
            ),
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(child: child),
              ],
            ),
            bottomNavigationBar: isWizard
                ? null
                : isInWizardFlow
                    ? _buildWizardNavBar(
                        context, ref,
                        stepIdx: wizardStepIdx,
                        stepRoutes: wizardStepRoutes,
                      )
                    : _buildBottomNavBar(
                        context, ref,
                        isMohaffez: isMohaffez,
                        isAdmin: isAdmin,
                        currentIndex: currentIndex,
                        unreadCount: unreadCount,
                      ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP BAR — unified teal across all roles
// ═══════════════════════════════════════════════════════════════════════════════
PreferredSizeWidget _buildAppBar(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required int currentIndex,
  required String userId,
  required int unreadCount,
}) {
  final currentPath = GoRouterState.of(context).uri.path;
  const rootShellPaths = {
    '/home', '/notifications', '/profile',
    '/mohaffez-home', '/admin-home',
  };
  final showBackButton = !rootShellPaths.contains(currentPath);

  // Gradient: teal for all roles — cohesive identity
  const gradient = LinearGradient(
    colors: [_ShellDS.teal800, _ShellDS.teal600],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  return PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: AppThemeConstants.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _ShellDS.white70, size: 20),
                tooltip: 'رجوع',
                onPressed: () {
                  try {
                    context.pop();
                  } catch (_) {
                    context.go('/home');
                  }
                },
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: _ShellDS.white70, size: 26),
                  tooltip: ArabicLabels.menu,
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo pill
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _ShellDS.white40,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _ShellDS.white70, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/icon.png',
                  height: 32, width: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.menu_book_rounded,
                    color: _ShellDS.white70, size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _screenTitle(isMohaffez, isAdmin, currentIndex),
              style: const TextStyle(
                  color: _ShellDS.white70,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: const [],
      ),
    ),
  );
}

String _screenTitle(bool isMohaffez, bool isAdmin, int currentIndex) {
  if (isMohaffez) {
    const t = [ArabicLabels.home, ArabicLabels.notifications, ArabicLabels.profile];
    return currentIndex < t.length ? t[currentIndex] : ArabicLabels.home;
  } else if (isAdmin) {
    const t = ['لوحة التحكم', 'الإشعارات', 'الملف الشخصي'];
    return currentIndex < t.length ? t[currentIndex] : 'لوحة التحكم';
  } else {
    const t = [ArabicLabels.home, ArabicLabels.notifications, ArabicLabels.profile];
    return currentIndex < t.length ? t[currentIndex] : ArabicLabels.home;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ═══════════════════════════════════════════════════════════════════════════════
// WIZARD NAVIGATION BAR — sequential Next / Finish bar shown during wizard flow
// ═══════════════════════════════════════════════════════════════════════════════
const _wizardStepLabels = [
  'الملف الشخصي',
  'الشهادات',
  'أوقات الفراغ',
  'المحفظة',
  'الأسعار والباقات',
];

Widget _buildWizardNavBar(
  BuildContext context,
  WidgetRef ref, {
  required int stepIdx,
  required List<String> stepRoutes,
}) {
  final isLast = stepIdx == stepRoutes.length - 1;
  final stepLabel = stepIdx >= 0 && stepIdx < _wizardStepLabels.length
      ? _wizardStepLabels[stepIdx]
      : '';

  void exitWizard() {
    ref.read(wizardModeProvider.notifier).state = false;
    context.go('/mohaffez-home');
  }

  void goNext() {
    if (isLast) {
      exitWizard();
    } else {
      context.push(stepRoutes[stepIdx + 1]);
    }
  }

  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF095752),
      boxShadow: [
        BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, -2)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Close button
            IconButton(
              onPressed: exitWizard,
              icon: const Icon(Icons.close_rounded, color: AppThemeConstants.white70, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'إغلاق',
            ),
            const SizedBox(width: 8),
            // Step label + counter
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stepLabel,
                    style: const TextStyle(
                      color: AppThemeConstants.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'الخطوة ${stepIdx + 1} من ${stepRoutes.length}',
                    style: const TextStyle(
                      color: AppThemeConstants.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Progress dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(stepRoutes.length, (i) {
                final isActive = i == stepIdx;
                final isDone = i < stepIdx;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF4CAF82)
                        : isActive
                            ? const Color(0xFFD4A44A)
                            : AppThemeConstants.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            // Next / Finish button
            ElevatedButton(
              onPressed: goNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFD4A44A),
                foregroundColor: AppThemeConstants.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLast ? 'إنهاء' : 'التالي'),
                  const SizedBox(width: 4),
                  Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_back_rounded,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION — custom design with active pill, clear icons, readable badge
// ═══════════════════════════════════════════════════════════════════════════════
Widget _buildBottomNavBar(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required int currentIndex,
  required int unreadCount,
}) {
  void onTap(int index) {
    ref.read(bottomNavIndexProvider.notifier).setIndex(index);
    final route = isMohaffez
        ? ['/mohaffez-home', '/notifications', '/profile'][index]
        : isAdmin
            ? ['/admin-home', '/notifications', '/profile'][index]
            : ['/home', '/notifications', '/profile'][index];
    context.go(route);
  }

  final homeIcon = isAdmin ? Icons.dashboard_rounded : Icons.home_rounded;
  final homeIconOutlined =
      isAdmin ? Icons.dashboard_outlined : Icons.home_outlined;
  final homeLabel = isAdmin ? 'لوحة التحكم' : ArabicLabels.home;

  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_ShellDS.teal800, _ShellDS.teal600],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      boxShadow: [
        BoxShadow(
            color: Color(0x40000000), blurRadius: 16, offset: Offset(0, -4)),
      ],
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: homeIconOutlined,
              activeIcon: homeIcon,
              label: homeLabel,
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications_rounded,
              label: ArabicLabels.notifications,
              selected: currentIndex == 1,
              badgeCount: unreadCount,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: ArabicLabels.profile,
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Selection accent: amber — stands out on teal, keeps labels readable.
    const accent = _ShellDS.amberLight;
    final iconColor = selected ? accent : _ShellDS.white70;
    final labelColor =
        selected ? accent : _ShellDS.white70.withValues(alpha: 0.78);

    return Expanded(
      child: Material(
        color: AppThemeConstants.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _ShellDS.white70.withValues(alpha: 0.12),
          highlightColor: _ShellDS.white70.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected
                            ? _ShellDS.white40
                            : AppThemeConstants.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.55)
                              : AppThemeConstants.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        selected ? activeIcon : icon,
                        size: 24,
                        color: iconColor,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -4,
                        child: _NavBadge(count: badgeCount),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.0,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: text.length > 1 ? 5 : 0, vertical: 0),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: AppThemeConstants.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeConstants.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.error.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: AppThemeConstants.surface,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWER — teal header, consistent with app identity
// ═══════════════════════════════════════════════════════════════════════════════
Widget _buildDrawer(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required bool isDevModeActive,
  required UserModel user,
}) {
  return Drawer(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        bottomLeft: Radius.circular(24),
      ),
    ),
    child: Column(
      children: [
        _DrawerHeader(user: user, isMohaffez: isMohaffez, isAdmin: isAdmin),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              // ── Common ──────────────────────────────────────────────────
              _drawerTile(context, title: ArabicLabels.profile,
                  icon: Icons.person_rounded, route: 'profile',
                  color: _ShellDS.teal500),
              _drawerTile(context, title: 'الإعدادات',
                  icon: Icons.settings_rounded, route: 'settings',
                  color: AppThemeConstants.textSecondary),
              _drawerTile(context, title: 'إعدادات الخصوصية',
                  icon: Icons.privacy_tip_rounded, route: 'privacy-settings',
                  color: AppThemeConstants.textSecondary),

              // ── Admin ────────────────────────────────────────────────────
              if (isAdmin) ...[
                _drawerSection('إدارة النظام'),
                _drawerTile(context, title: 'لوحة التحكم',
                    icon: Icons.dashboard_rounded, route: 'admin-home',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'المستخدمون',
                    icon: Icons.people_alt_rounded, route: 'admin/users',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'الاعتمادات',
                    icon: Icons.verified_rounded, route: 'admin/credentials',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'العمليات الفاشلة',
                    icon: Icons.warning_amber_rounded, route: 'admin/failed-ops',
                    color: AppThemeConstants.warning),
                _drawerTile(context, title: 'أكواد الخصم',
                    icon: Icons.discount_rounded, route: 'admin/promo-codes',
                    color: _ShellDS.teal600),
                _drawerTile(context, title: 'قفل المواعيد',
                    icon: Icons.lock_clock_rounded, route: 'admin/slot-locks',
                    color: AppThemeConstants.textSecondary),
                _drawerTile(context, title: 'أحداث الدفع',
                    icon: Icons.payment_rounded, route: 'admin/payment-events',
                    color: _ShellDS.teal600),
                _drawerTile(context, title: 'العمولات',
                    icon: Icons.analytics_rounded, route: 'admin/commissions',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'الإشعارات الجماعية',
                    icon: Icons.campaign_rounded, route: 'admin/broadcast',
                    color: AppThemeConstants.warning),
                _drawerTile(context, title: 'إعدادات النظام',
                    icon: Icons.settings_rounded, route: 'admin/settings',
                    color: AppThemeConstants.textSecondary),
                if (isDevModeActive)
                  _drawerTile(context, title: 'وضع المطوّر',
                      icon: Icons.bug_report_rounded, route: 'admin/dev-mode',
                      color: AppThemeConstants.error),
                _drawerTile(context, title: 'عمولات المحفظين',
                    icon: Icons.account_balance_rounded,
                    route: 'admin/teacher-commissions', color: _ShellDS.teal600),
                _drawerTile(context, title: 'أرقام محافظ المنصة',
                    icon: Icons.account_balance_wallet_rounded,
                    route: 'admin/wallet-numbers', color: _ShellDS.teal500),
                _drawerTile(context, title: 'سجل العمليات',
                    icon: Icons.history_rounded, route: 'admin/audit-log',
                    color: AppThemeConstants.textSecondary),
              ],

              // ── Mohaffez ─────────────────────────────────────────────────
              if (isMohaffez) ...[
                _drawerSection('دليل الإعداد'),
                _SetupGuideDrawerTile(uid: user.uid),
                _drawerSection('أدوات المحفظ'),
                _drawerTile(context, title: 'بيانات الاعتماد',
                    icon: Icons.verified_user_rounded, route: 'credentials',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'إدارة الجدول',
                    icon: Icons.schedule_rounded, route: 'availability',
                    color: _ShellDS.teal600),
                _drawerTile(context, title: 'إدارة الأسعار',
                    icon: Icons.sell_rounded, route: 'pricing-management',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'إعدادات المحفظة',
                    icon: Icons.account_balance_wallet_rounded,
                    route: 'wallet-settings', color: _ShellDS.teal600),
                _drawerTile(context, title: 'تأكيد المدفوعات',
                    icon: Icons.payments_rounded, route: 'direct-payment-confirmations',
                    color: AppThemeConstants.warning),
              ],

              // ── Student extras ────────────────────────────────────────────
              if (!isMohaffez && !isAdmin) ...[
                _drawerSection('باقاتي'),
                _drawerTile(context, title: 'باقاتي النشطة',
                    icon: Icons.collections_bookmark_rounded, route: 'active-subscriptions',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'طلباتي',
                    icon: Icons.pending_actions_rounded, route: 'requests',
                    color: AppThemeConstants.warning),
              ],

              const Divider(height: 28, indent: 16, endIndent: 16),

              // ── Logout ───────────────────────────────────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppThemeConstants.error, size: 20),
                ),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: AppThemeConstants.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () async {
                  context.pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                        actions: [
                          TextButton(
                            onPressed: () => context.pop(false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeConstants.error,
                              foregroundColor: AppThemeConstants.surface,
                            ),
                            onPressed: () => context.pop(true),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirmed == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWER HEADER — teal gradient, matches AppBar exactly
// ═══════════════════════════════════════════════════════════════════════════════
class _DrawerHeader extends StatelessWidget {
  final UserModel user;
  final bool isMohaffez;
  final bool isAdmin;

  const _DrawerHeader({required this.user, required this.isMohaffez, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final name  = user.name;
    final email = user.email;
    final roleLabel = isAdmin
        ? 'مدير النظام'
        : isMohaffez
            ? 'محفظ معتمد'
            : 'طالب';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_ShellDS.teal800, _ShellDS.teal600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _ShellDS.white40,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _ShellDS.white70, width: 2),
                ),
                child: Center(
                  child: Text(
                    _getAvatarInitial(name),
                    style: const TextStyle(
                        color: _ShellDS.white70, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + email + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _ShellDS.white70, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ShellDS.white70, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _ShellDS.white15,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _ShellDS.white40, width: 1),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                            color: _ShellDS.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _getAvatarInitial(String name) {
  if (name.isEmpty) return '؟';
  final trimmed = name.trim();
  if (trimmed.startsWith('ال')) {
    if (trimmed.length > 2) return trimmed[2];
    return trimmed[0];
  }
  return trimmed[0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWER TILE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
Widget _drawerTile(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String route,
  Color? color,
}) {
  final c = color ?? AppThemeConstants.textSecondary;
  return ListTile(
    dense: true,
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: c),
    ),
    title: Text(
      title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppThemeConstants.textPrimary),
    ),
    trailing: const Icon(Icons.arrow_back_ios_new_rounded,
        size: 13, color: AppThemeConstants.textMuted),
    onTap: () {
      context.pop();
      context.go('/$route');
    },
  );
}

Widget _drawerSection(String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppThemeConstants.textMuted,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETUP GUIDE DRAWER TILE — shows live "X/5" progress badge
// ═══════════════════════════════════════════════════════════════════════════════
class _SetupGuideDrawerTile extends ConsumerWidget {
  final String uid;
  const _SetupGuideDrawerTile({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(teacherSetupProvider);
    final completed = progressAsync.value?.completedCount ?? 0;
    final allDone = progressAsync.value?.allDone ?? false;
    final color = allDone ? const Color(0xFF2E8B57) : _ShellDS.teal500;
    final bgColor = allDone
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFEAF6F3);

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.rocket_launch_rounded, size: 20, color: color),
      ),
      title: const Text(
        'دليل الإعداد السريع',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppThemeConstants.textPrimary,
        ),
      ),
      trailing: progressAsync.isLoading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: allDone ? const Color(0xFF2E8B57) : _ShellDS.teal500,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                allDone ? 'مكتمل ✓' : '$completed/5',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppThemeConstants.white,
                ),
              ),
            ),
      onTap: () {
        ref.read(wizardModeProvider.notifier).state = true;
        context.pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            context.push('/profile');
          }
        });
      },
    );
  }
}
