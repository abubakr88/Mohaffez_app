import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notification_provider_paginated.dart';
import '../providers/system_config_provider.dart';
import '../utils/arabic_labels.dart';
import 'direct_payment_confirmations_screen.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    // Handle loading and error states properly instead of null-checking value
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

        final currentIndex  = ref.watch(bottomNavIndexProvider);
        final isMohaffez    = user.role == 'mohaffez';
        final isAdmin       = user.role == 'admin';
        final isDevModeActive = ref.watch(isDevModeActiveProvider);

        // Read unread count once here — shared by AppBar badge AND BottomNav badge
        final unreadCount = ref
            .watch(unreadNotificationsCountProvider(user.uid))
            .value ?? 0;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
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
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ════════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref, {
    required bool isMohaffez,
    required bool isAdmin,
    required int currentIndex,
    required String userId,
    required int unreadCount,
  }) {
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

          // Keep status bar icons white over the amber gradient
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),

      // ── LEADING (right in RTL) ─────────────────────────────────────
      // Back arrow on sub-routes, hamburger on root tabs
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'رجوع',
              onPressed: () {
                // WHY: GoRouter's context.canPop() can return true even when
                // the underlying Navigator stack is empty after context.go()
                // resets subroutes inside a ShellRoute — causing a GoError crash.
                // Fallback to /home keeps UX clean instead of crashing.
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
          // ── TITLE ──────────────────────────────────────────────────────
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/icon.png',
                  height: 30,
                  width: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    color: AppTheme.primaryAmber,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _getScreenTitle(isMohaffez, isAdmin, currentIndex),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // ── ACTIONS (left in RTL) ──────────────────────────────────────
          // Notification bell only. No refresh button.
          actions: [
            if (!isAdmin)
              _buildNotificationBell(
                context, ref,
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

  String _getScreenTitle(bool isMohaffez, bool isAdmin, int currentIndex) {
    if (isMohaffez) {
      const titles = [
        ArabicLabels.home,
        ArabicLabels.notifications,
        ArabicLabels.profile,
      ];
      return currentIndex < titles.length ? titles[currentIndex] : 'محفظ';
    } else if (isAdmin) {
      const titles = ['لوحة التحكم', 'المستخدمون', 'المدفوعات', 'الإعدادات'];
      return currentIndex < titles.length ? titles[currentIndex] : 'لوحة التحكم';
    } else {
      const titles = [
        ArabicLabels.home,
        ArabicLabels.search,
        ArabicLabels.notifications,
        ArabicLabels.profile,
      ];
      return currentIndex < titles.length ? titles[currentIndex] : 'محفظ';
    }
  }

  Widget _buildNotificationBell(
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

  // ════════════════════════════════════════════════════════════════════════════
  // DRAWER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref, {
    required bool isMohaffez,
    required bool isAdmin,
    required bool isDevModeActive,
    required dynamic user,
  }) {
    return Drawer(
      // Rounded corners on the open edge (left in RTL)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(user, isMohaffez: isMohaffez, isAdmin: isAdmin),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [

                // ── Common ────────────────────────────────────────────────
                _drawerTile(context,
                  title: ArabicLabels.profile,
                  icon: Icons.person_rounded,
                  route: '/profile',
                ),

                // ── Admin ─────────────────────────────────────────────────
                if (isAdmin) ...[
                  _drawerSectionLabel('إدارة النظام'),
                  _drawerTile(context, title: 'لوحة التحكم',        icon: Icons.dashboard_rounded,      route: '/admin-home'),
                  _drawerTile(context, title: 'إدارة المستخدمين',   icon: Icons.people_alt_rounded,     route: '/admin/users'),
                  _drawerTile(context, title: 'مراجعة الشهادات',    icon: Icons.verified_rounded,       route: '/admin/credentials'),
                  _drawerTile(context, title: 'العمليات الفاشلة',   icon: Icons.warning_amber_rounded,  route: '/admin/failed-ops',        color: Colors.orange),
                  _drawerTile(context, title: 'أكواد الخصم',        icon: Icons.discount_rounded,       route: '/admin/promo-codes'),
                  _drawerTile(context, title: 'القفلات النشطة',     icon: Icons.lock_clock_rounded,     route: '/admin/slot-locks'),
                  _drawerTile(context, title: 'أحداث الدفع',        icon: Icons.payment_rounded,        route: '/admin/payment-events'),
                  _drawerTile(context, title: 'العمولات',           icon: Icons.analytics_rounded,      route: '/admin/commissions'),
                  _drawerTile(context, title: 'إشعارات جماعية',     icon: Icons.campaign_rounded,       route: '/admin/broadcast'),
                  _drawerTile(context, title: 'إعدادات النظام',     icon: Icons.settings_rounded,       route: '/admin/settings'),
                  if (isDevModeActive)
                    _drawerTile(context, title: 'DEV MODE',          icon: Icons.bug_report_rounded,     route: '/admin/dev-mode',           color: Colors.red),
                ],

                // ── Mohaffez ──────────────────────────────────────────────
                if (isMohaffez) ...[
                  _drawerSectionLabel('إدارة الحساب'),
                  _drawerTile(context, title: 'الشهادات والمؤهلات', icon: Icons.verified_user_rounded,  route: '/credentials',             color: Colors.purple),
                  _drawerTile(context, title: 'إدارة الأوقات',      icon: Icons.schedule_rounded,       route: '/availability',            color: Colors.blue),
                  // Direct payment — pushes a new route, not go()
                  _drawerCustomTile(
                    context,
                    title: 'مدفوعات بانتظار التأكيد',
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

                // ── General ───────────────────────────────────────────────
                _drawerSectionLabel('عام'),
                _drawerTile(context, title: ArabicLabels.settings, icon: Icons.settings_rounded,   route: '/settings'),
                _drawerTile(context, title: ArabicLabels.privacy,  icon: Icons.privacy_tip_rounded, route: '/privacy-settings'),

                const Divider(height: 24, indent: 16, endIndent: 16),

                // ── Logout ────────────────────────────────────────────────
                _drawerCustomTile(
                  context,
                  title: 'تسجيل الخروج',
                  icon: Icons.logout_rounded,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context, ref);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(
    dynamic user, {
    required bool isMohaffez,
    required bool isAdmin,
  }) {
    final roleLabel = isAdmin ? 'مشرف' : isMohaffez ? 'محفظ' : 'طالب';
    final roleColor = isAdmin
        ? Colors.red.shade700
        : isMohaffez
            ? Colors.purple.shade600
            : Colors.blue.shade600;

    return DrawerHeader(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'م',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAmber,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    Color? color,
  }) {
    return _drawerCustomTile(
      context,
      title: title,
      icon: icon,
      color: color,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }

  Widget _drawerCustomTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? AppTheme.primaryAmber;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: tileColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: tileColor, size: 19),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('تسجيل الخروج'),
            ],
          ),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV BAR
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref, {
    required bool isMohaffez,
    required bool isAdmin,
    required int currentIndex,
    required int unreadCount,
  }) {
    if (isAdmin) {
      return _styledBottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(i);
          const routes = [
            '/admin-home',
            '/admin/users',
            '/admin/payment-events',
            '/admin/settings',
          ];
          if (i < routes.length) context.go(routes[i]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),   label: 'لوحة التحكم'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded),  label: 'المستخدمون'),
          BottomNavigationBarItem(icon: Icon(Icons.payment_rounded),     label: 'المدفوعات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded),    label: 'الإعدادات'),
        ],
      );
    } else if (isMohaffez) {
      return _styledBottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(i);
          const routes = ['/mohaffez-home', '/notifications', '/profile'];
          if (i < routes.length) context.go(routes[i]);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded),   label: 'الرئيسية'),
          BottomNavigationBarItem(icon: _badgedBellIcon(unreadCount),      label: 'الإشعارات'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'الملف الشخصي'),
        ],
      );
    } else {
      return _styledBottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(i);
          const routes = ['/home', '/nearby', '/notifications', '/profile'];
          if (i < routes.length) context.go(routes[i]);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded),   label: 'الرئيسية'),
          const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'البحث'),
          BottomNavigationBarItem(icon: _badgedBellIcon(unreadCount),      label: 'الإشعارات'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'الملف الشخصي'),
        ],
      );
    }
  }

  /// Bell icon with a Material 3 Badge for the BottomNavigationBar
  Widget _badgedBellIcon(int unreadCount) {
    return Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        style: const TextStyle(fontSize: 9),
      ),
      child: Icon(
        unreadCount > 0
            ? Icons.notifications_active_rounded
            : Icons.notifications_outlined,
      ),
    );
  }

  Widget _styledBottomNav({
    required int currentIndex,
    required void Function(int) onTap,
    required List<BottomNavigationBarItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 0, // shadow handled by Container above
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: items,
      ),
    );
  }
}
