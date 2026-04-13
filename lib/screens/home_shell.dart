// lib/screens/home_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/navigation_provider.dart';
import '../providers/notification_provider_paginated.dart';
import '../providers/payment_provider.dart';
import '../providers/system_config_provider.dart';
import '../providers/user_provider.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/offline_banner.dart';
import '../utils/arabic_labels.dart';
import 'direct_payment_confirmations_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SHELL DESIGN TOKENS — keep in sync with mohaffez_home.dart _DS
// ═══════════════════════════════════════════════════════════════════════════════
class _ShellDS {
  // Teal brand (teacher / mohaffez)
  static const teal800 = Color(0xFF095752);
  static const teal600 = Color(0xFF0E8278);
  static const teal500 = Color(0xFF1A9E84);
  static const teal50  = Color(0xFFEAF6F3);

  // Student / Admin use the original amber palette
  static const amber     = Color(0xFFD4840A);
  static const amberLight= Color(0xFFF5A623);

  // Neutral
  static const white70 = Color(0xB3FFFFFF);
  static const white40 = Color(0x66FFFFFF);
  static const white15 = Color(0x26FFFFFF);

  // Bottom nav background (shared)
  static const navBg   = Color(0xFF0C6F6A);  // teal for mohaffez
  static const navBgStudent = Color(0xFF0C6F6A); // keep consistent app-wide
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

        final bundleCount = (!isMohaffez && !isAdmin)
            ? (ref.watch(activeSubscriptionsProvider(user.uid)).value?.length ?? 0)
            : 0;

        // Status bar brightness: always light icons (we always use dark background)
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ));

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7F6),
            appBar: _buildAppBar(
              context, ref,
              isMohaffez: isMohaffez,
              isAdmin: isAdmin,
              currentIndex: currentIndex,
              userId: user.uid,
              unreadCount: unreadCount,
            ),
            drawer: _buildDrawer(
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
            bottomNavigationBar: _buildBottomNavBar(
              context, ref,
              isMohaffez: isMohaffez,
              isAdmin: isAdmin,
              currentIndex: currentIndex,
              unreadCount: unreadCount,
              bundleCount: bundleCount,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
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
                      color: Colors.white, size: 26),
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
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/icon.png',
                  height: 32, width: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _screenTitle(isMohaffez, isAdmin, currentIndex),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          if (!isAdmin)
            _NotificationBell(
              isMohaffez: isMohaffez,
              userId: userId,
              unreadCount: unreadCount,
              ref: ref,
            ),
          const SizedBox(width: 6),
        ],
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
class _NotificationBell extends ConsumerWidget {
  final bool isMohaffez;
  final String userId;
  final int unreadCount;
  final WidgetRef ref;

  const _NotificationBell({
    required this.isMohaffez,
    required this.userId,
    required this.unreadCount,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            unreadCount > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_outlined,
            color: Colors.white, size: 26,
          ),
          tooltip: ArabicLabels.notifications,
          onPressed: () {
            ref.read(bottomNavIndexProvider.notifier).setIndex(isMohaffez ? 1 : 2);
            context.go('/notifications');
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
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
  int bundleCount = 0,
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
    final iconColor = selected ? accent : Colors.white;
    final labelColor =
        selected ? accent : Colors.white.withValues(alpha: 0.78);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
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
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.55)
                              : Colors.transparent,
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
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
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
  required dynamic user,
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
                  color: Colors.grey.shade600),
              _drawerTile(context, title: 'إعدادات الخصوصية',
                  icon: Icons.privacy_tip_rounded, route: 'privacy-settings',
                  color: Colors.grey.shade600),

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
                    color: Colors.orange),
                _drawerTile(context, title: 'أكواد الخصم',
                    icon: Icons.discount_rounded, route: 'admin/promo-codes',
                    color: _ShellDS.teal600),
                _drawerTile(context, title: 'قفل المواعيد',
                    icon: Icons.lock_clock_rounded, route: 'admin/slot-locks',
                    color: Colors.blueGrey),
                _drawerTile(context, title: 'أحداث الدفع',
                    icon: Icons.payment_rounded, route: 'admin/payment-events',
                    color: _ShellDS.teal600),
                _drawerTile(context, title: 'العمولات',
                    icon: Icons.analytics_rounded, route: 'admin/commissions',
                    color: _ShellDS.teal500),
                _drawerTile(context, title: 'الإشعارات الجماعية',
                    icon: Icons.campaign_rounded, route: 'admin/broadcast',
                    color: Colors.orange),
                _drawerTile(context, title: 'إعدادات النظام',
                    icon: Icons.settings_rounded, route: 'admin/settings',
                    color: Colors.grey.shade600),
                if (isDevModeActive)
                  _drawerTile(context, title: 'وضع المطوّر',
                      icon: Icons.bug_report_rounded, route: 'admin/dev-mode',
                      color: Colors.red),
                _drawerTile(context, title: 'عمولات المحفظين',
                    icon: Icons.account_balance_rounded,
                    route: 'admin/teacher-commissions', color: _ShellDS.teal600),
                _drawerTile(context, title: 'أرقام محافظ المنصة',
                    icon: Icons.account_balance_wallet_rounded,
                    route: 'admin/wallet-numbers', color: _ShellDS.teal500),
                _drawerTile(context, title: 'سجل العمليات',
                    icon: Icons.history_rounded, route: 'admin/audit-log',
                    color: Colors.grey.shade600),
              ],

              // ── Mohaffez ─────────────────────────────────────────────────
              if (isMohaffez) ...[
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
                _drawerCustomTile(
                  context,
                  title: 'تأكيد المدفوعات',
                  icon: Icons.payments_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DirectPaymentConfirmationsScreen()),
                    );
                  },
                ),
              ],

              // ── Student extras ────────────────────────────────────────────
              if (!isMohaffez && !isAdmin) ...[
                _drawerSection('باقاتي'),
                _drawerCustomTile(
                  context,
                  title: 'باقاتي النشطة',
                  icon: Icons.collections_bookmark_rounded,
                  color: _ShellDS.teal500,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/active-subscriptions');
                  },
                ),
                _drawerTile(context, title: 'طلباتي',
                    icon: Icons.pending_actions_rounded, route: 'requests',
                    color: Colors.orange),
              ],

              const Divider(height: 28, indent: 16, endIndent: 16),

              // ── Logout ───────────────────────────────────────────────────
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                ),
                title: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
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
  final dynamic user;
  final bool isMohaffez;
  final bool isAdmin;

  const _DrawerHeader({required this.user, required this.isMohaffez, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final name  = (user?.name as String?) ?? 'المستخدم';
    final email = (user?.email as String?) ?? '';
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
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : '؟',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
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
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72), fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28), width: 1),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
  final c = color ?? Colors.grey.shade700;
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
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
    ),
    trailing: Icon(Icons.arrow_back_ios_new_rounded,
        size: 13, color: Colors.grey.shade400),
    onTap: () {
      Navigator.pop(context);
      context.go('/$route');
    },
  );
}

Widget _drawerCustomTile(
  BuildContext context, {
  required String title,
  required IconData icon,
  Color? color,
  required VoidCallback onTap,
}) {
  final c = color ?? Colors.grey.shade700;
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
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
    ),
    trailing: Icon(Icons.arrow_back_ios_new_rounded,
        size: 13, color: Colors.grey.shade400),
    onTap: onTap,
  );
}

Widget _drawerSection(String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC HELPERS kept for backward compatibility with any remaining call-sites
// ═══════════════════════════════════════════════════════════════════════════════
PreferredSizeWidget buildAppBar(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required int currentIndex,
  required String userId,
  required int unreadCount,
}) =>
    _buildAppBar(context, ref,
        isMohaffez: isMohaffez,
        isAdmin: isAdmin,
        currentIndex: currentIndex,
        userId: userId,
        unreadCount: unreadCount);

Widget buildBottomNavBar(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required int currentIndex,
  required int unreadCount,
  int bundleCount = 0,
}) =>
    _buildBottomNavBar(context, ref,
        isMohaffez: isMohaffez,
        isAdmin: isAdmin,
        currentIndex: currentIndex,
        unreadCount: unreadCount,
        bundleCount: bundleCount);

Widget buildDrawer(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required bool isDevModeActive,
  required dynamic user,
}) =>
    _buildDrawer(context, ref,
        isMohaffez: isMohaffez,
        isAdmin: isAdmin,
        isDevModeActive: isDevModeActive,
        user: user);

String getScreenTitle(bool isMohaffez, bool isAdmin, int currentIndex) =>
    _screenTitle(isMohaffez, isAdmin, currentIndex);

Widget buildNotificationBell(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required String userId,
  required int unreadCount,
}) =>
    _NotificationBell(
        isMohaffez: isMohaffez,
        userId: userId,
        unreadCount: unreadCount,
        ref: ref);

Widget buildDrawerHeader(
  dynamic user, {
  required bool isMohaffez,
  required bool isAdmin,
}) =>
    _DrawerHeader(user: user, isMohaffez: isMohaffez, isAdmin: isAdmin);