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

// ============================================================
// HOME SHELL
// ============================================================
class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentIndex = ref.watch(bottomNavIndexProvider);
        final isMohaffez = user.role == 'mohaffez';
        final isAdmin = user.role == 'admin';
        final isDevModeActive = ref.watch(isDevModeActiveProvider);

        // Shared: unread notification count (AppBar + BottomNav badge)
        final unreadCount = ref
            .watch(unreadNotificationsCountProvider(user.uid))
            .value ?? 0;

        // Student only: active bundle count for home tab badge
        final bundleCount = (!isMohaffez && !isAdmin)
            ? (ref.watch(activeSubscriptionsProvider(user.uid)).value?.length ?? 0)
            : 0;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: buildAppBar(
              context,
              ref,
              isMohaffez: isMohaffez,
              isAdmin: isAdmin,
              currentIndex: currentIndex,
              userId: user.uid,
              unreadCount: unreadCount,
            ),
            drawer: buildDrawer(
              context,
              ref,
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
            bottomNavigationBar: buildBottomNavBar(
              context,
              ref,
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

// ============================================================
// APP BAR
// ============================================================
PreferredSizeWidget buildAppBar(
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
    '/home',
    '/notifications',
    '/profile',
    '/mohaffez-home',
    '/admin-home',
  };
  final showBackButton = !rootShellPaths.contains(currentPath);

  return PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'رجوع',
                onPressed: () {
                  // WHY: GoRouter's context.canPop can return true even on
                  // empty stacks inside a ShellRoute → fallback to /home.
                  try {
                    context.pop();
                  } catch (_) {
                    context.go('/home');
                  }
                },
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  tooltip: ArabicLabels.menu,
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/icon.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              getScreenTitle(isMohaffez, isAdmin, currentIndex),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          if (!isAdmin)
            buildNotificationBell(
              context,
              ref,
              isMohaffez: isMohaffez,
              userId: userId,
              unreadCount: unreadCount,
            ),
          const SizedBox(width: 4),
        ],
      ),
    ),
  );
}

// ── Screen title helper ───────────────────────────────────────
String getScreenTitle(bool isMohaffez, bool isAdmin, int currentIndex) {
  if (isMohaffez) {
    const titles = [
      ArabicLabels.home,
      ArabicLabels.notifications,
      ArabicLabels.profile,
    ];
    return currentIndex < titles.length ? titles[currentIndex] : ArabicLabels.home;
  } else if (isAdmin) {
    const titles = ['لوحة التحكم', 'الإشعارات', 'الملف الشخصي'];
    return currentIndex < titles.length ? titles[currentIndex] : 'لوحة التحكم';
  } else {
    const titles = [
      ArabicLabels.home,
      ArabicLabels.search,
      ArabicLabels.notifications,
      ArabicLabels.profile,
    ];
    return currentIndex < titles.length ? titles[currentIndex] : ArabicLabels.home;
  }
}

// ── Notification bell with badge ─────────────────────────────
Widget buildNotificationBell(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required String userId,
  required int unreadCount,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        icon: Icon(
          unreadCount > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_outlined,
          color: Colors.white,
          size: 26,
        ),
        tooltip: ArabicLabels.notifications,
        onPressed: () {
          ref
              .read(bottomNavIndexProvider.notifier)
              .setIndex(isMohaffez ? 1 : 2);
          context.go('/notifications');
        },
      ),
      if (unreadCount > 0)
        Positioned(
          right: 6,
          top: 6,
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
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  );
}

// ============================================================
// BOTTOM NAVIGATION BAR
// ============================================================
Widget buildBottomNavBar(
  BuildContext context,
  WidgetRef ref, {
  required bool isMohaffez,
  required bool isAdmin,
  required int currentIndex,
  required int unreadCount,
  int bundleCount = 0,
}) {
  // ── Shared styling ──────────────────────────────────────────
  const selectedColor = AppTheme.primaryAmber;
  const unselectedColor = Colors.grey;

  // ── Notification badge item builder ────────────────────────
  BottomNavigationBarItem notifItem() => BottomNavigationBarItem(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        activeIcon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_rounded),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: ArabicLabels.notifications,
      );

  // ── Student ─────────────────────────────────────────────────
  if (!isMohaffez && !isAdmin) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
      unselectedItemColor: const Color.fromARGB(255, 255, 255, 255),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      elevation: 12,
      onTap: (index) {
        ref.read(bottomNavIndexProvider.notifier).setIndex(index);
        switch (index) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/notifications');
          case 2:
            context.go('/profile');
        }
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: ArabicLabels.home,
        ),
        notifItem(),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: ArabicLabels.profile,
        ),
      ],
    );
  }

  // ── Mohaffez ────────────────────────────────────────────────
  if (isMohaffez) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
      unselectedItemColor: const Color.fromARGB(255, 255, 255, 255),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      elevation: 12,
      onTap: (index) {
        ref.read(bottomNavIndexProvider.notifier).setIndex(index);
        switch (index) {
          case 0:
            context.go('/mohaffez-home');
          case 1:
            context.go('/notifications');
          case 2:
            context.go('/profile');
        }
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: ArabicLabels.home,
        ),
        notifItem(),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: ArabicLabels.profile,
        ),
      ],
    );
  }

  // ── Admin ───────────────────────────────────────────────────
  return BottomNavigationBar(
    currentIndex: currentIndex,
    selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
    unselectedItemColor: unselectedColor,
    type: BottomNavigationBarType.fixed,
    selectedLabelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: const TextStyle(fontSize: 11),
    elevation: 12,
    onTap: (index) {
      ref.read(bottomNavIndexProvider.notifier).setIndex(index);
      switch (index) {
        case 0:
          context.go('/admin-home');
        case 1:
          context.go('/notifications');
        case 2:
          context.go('/profile');
      }
    },
    items: [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard_rounded),
        label: 'لوحة التحكم',
      ),
      notifItem(),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: ArabicLabels.profile,
      ),
    ],
  );
}

// ============================================================
// DRAWER
// ============================================================
Widget buildDrawer(
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
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
    ),
    child: Column(
      children: [
        buildDrawerHeader(user, isMohaffez: isMohaffez, isAdmin: isAdmin),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            children: [
              // ── Common ──────────────────────────────────────
              drawerTile(
                context,
                title: ArabicLabels.profile,
                icon: Icons.person_rounded,
                route: 'profile',
              ),
              drawerTile(
                context,
                title: 'الإعدادات',
                icon: Icons.settings_rounded,
                route: 'settings',
              ),
              drawerTile(
                context,
                title: 'إعدادات الخصوصية',
                icon: Icons.privacy_tip_rounded,
                route: 'privacy-settings',
              ),

              // ── Admin ────────────────────────────────────────
              if (isAdmin) ...[
                drawerSectionLabel('إدارة النظام'),
                drawerTile(context,
                    title: 'لوحة التحكم',
                    icon: Icons.dashboard_rounded,
                    route: 'admin-home'),
                drawerTile(context,
                    title: 'المستخدمون',
                    icon: Icons.people_alt_rounded,
                    route: 'admin/users'),
                drawerTile(context,
                    title: 'الاعتمادات',
                    icon: Icons.verified_rounded,
                    route: 'admin/credentials'),
                drawerTile(context,
                    title: 'العمليات الفاشلة',
                    icon: Icons.warning_amber_rounded,
                    route: 'admin/failed-ops',
                    color: Colors.orange),
                drawerTile(context,
                    title: 'أكواد الخصم',
                    icon: Icons.discount_rounded,
                    route: 'admin/promo-codes'),
                drawerTile(context,
                    title: 'قفل المواعيد',
                    icon: Icons.lock_clock_rounded,
                    route: 'admin/slot-locks'),
                drawerTile(context,
                    title: 'أحداث الدفع',
                    icon: Icons.payment_rounded,
                    route: 'admin/payment-events'),
                drawerTile(context,
                    title: 'العمولات',
                    icon: Icons.analytics_rounded,
                    route: 'admin/commissions'),
                drawerTile(context,
                    title: 'الإشعارات الجماعية',
                    icon: Icons.campaign_rounded,
                    route: 'admin/broadcast'),
                drawerTile(context,
                    title: 'إعدادات النظام',
                    icon: Icons.settings_rounded,
                    route: 'admin/settings'),
                if (isDevModeActive)
                  drawerTile(context,
                      title: 'وضع المطوّر',
                      icon: Icons.bug_report_rounded,
                      route: 'admin/dev-mode',
                      color: Colors.red),
                drawerTile(context,
                    title: 'عمولات المحافظين',
                    icon: Icons.account_balance_rounded,
                    route: 'admin/teacher-commissions'),
                drawerTile(context,
                    title: 'أرقام محافظ المنصة',
                    icon: Icons.account_balance_wallet_rounded,
                    route: 'admin/wallet-numbers'),
                drawerTile(context,
                    title: 'سجل العمليات',
                    icon: Icons.history_rounded,
                    route: 'admin/audit-log'),
              ],

              // ── Mohaffez ─────────────────────────────────────
              if (isMohaffez) ...[
                drawerSectionLabel('أدوات المحفظ'),
                drawerTile(context,
                    title: 'بيانات الاعتماد',
                    icon: Icons.verified_user_rounded,
                    route: 'credentials',
                    color: Colors.purple),
                drawerTile(context,
                    title: 'إدارة الجدول',
                    icon: Icons.schedule_rounded,
                    route: 'availability',
                    color: Colors.blue),
                drawerTile(context,
                    title: 'إدارة الأسعار',
                    icon: Icons.price_change_rounded,
                    route: 'pricing-management',
                    color: Colors.teal),
                drawerTile(context,
                    title: 'إعدادات المحفظة',
                    icon: Icons.account_balance_wallet_rounded,
                    route: 'wallet-settings',
                    color: Colors.green),
                drawerCustomTile(
                  context,
                  title: 'تأكيد المدفوعات',
                  icon: Icons.payments_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const DirectPaymentConfirmationsScreen(),
                      ),
                    );
                  },
                ),
              ],

              // ── Student extras ───────────────────────────────
              if (!isMohaffez && !isAdmin) ...[
                drawerSectionLabel('باقاتي'),
                drawerCustomTile(
                  context,
                  title: 'باقاتي النشطة',
                  icon: Icons.collections_bookmark_rounded,
                  color: AppTheme.primaryAmber,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/active-subscriptions');
                  },
                ),
                drawerTile(context,
                    title: 'طلباتي',
                    icon: Icons.pending_actions_rounded,
                    route: 'requests',
                    color: Colors.orange),
              ],

              const Divider(height: 24),

              // ── Logout ───────────────────────────────────────
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
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

// ── Drawer header ─────────────────────────────────────────────
Widget buildDrawerHeader(
  dynamic user, {
  required bool isMohaffez,
  required bool isAdmin,
}) {
  final name = (user?.name as String?) ?? 'المستخدم';
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
        colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            if (email.isNotEmpty)
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            // Role chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// DRAWER TILE HELPERS
// ============================================================
Widget drawerTile(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String route,
  Color? color,
}) {
  final tileColor = color ?? Colors.grey.shade700;
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tileColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: tileColor),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
    ),
    trailing: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 14,
      color: Colors.grey.shade400,
    ),
    onTap: () {
      Navigator.pop(context);
      context.go('/$route');
    },
  );
}

Widget drawerCustomTile(
  BuildContext context, {
  required String title,
  required IconData icon,
  Color? color,
  required VoidCallback onTap,
}) {
  final tileColor = color ?? Colors.grey.shade700;
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tileColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: tileColor),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
    ),
    trailing: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 14,
      color: Colors.grey.shade400,
    ),
    onTap: onTap,
  );
}

Widget drawerSectionLabel(String label) {
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
