import 'package:flutter/material.dart';
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
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentIndex = ref.watch(bottomNavIndexProvider);
    final isMohaffez = user.role == 'mohaffez';
    final isAdmin = user.role == 'admin';
    final isDevModeActive = ref.watch(isDevModeActiveProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(context, ref, isMohaffez, isAdmin, currentIndex,
            user.uid, user.name),
        drawer: _buildDrawer(
            context, ref, isMohaffez, isAdmin, isDevModeActive, user),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar:
            _buildBottomNavBar(context, ref, isMohaffez, isAdmin, currentIndex),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    bool isAdmin,
    int currentIndex,
    String userId,
    String userName,
  ) {
    String getTitle() {
      if (isMohaffez) {
        switch (currentIndex) {
          case 0:
            return ArabicLabels.home;
          case 1:
            return ArabicLabels.notifications;
          case 2:
            return ArabicLabels.profile;
          default:
            return 'محفظ';
        }
      } else if (isAdmin) {
        switch (currentIndex) {
          case 0:
            return 'لوحة التحكم';
          case 1:
            return 'المستخدمون';
          case 2:
            return 'المدفوعات';
          case 3:
            return 'الإعدادات';
          default:
            return 'لوحة التحكم';
        }
      } else {
        switch (currentIndex) {
          case 0:
            return ArabicLabels.home;
          case 1:
            return ArabicLabels.search;
          case 2:
            return ArabicLabels.notifications;
          case 3:
            return ArabicLabels.profile;
          default:
            return 'محفظ';
        }
      }
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
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
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    color: AppTheme.primaryAmber,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(getTitle()),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: ArabicLabels.menu,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => ref.invalidate(currentUserProvider),
            ),
            if (!isAdmin && currentIndex != (isMohaffez ? 1 : 2))
              _buildNotificationBadge(context, ref, isMohaffez, userId),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    String userId,
  ) {
    final unreadCountAsync =
        ref.watch(unreadNotificationsCountProvider(userId));
    return unreadCountAsync.when(
      data: (unreadCount) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
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
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () => context.go('/notifications'),
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () => context.go('/notifications'),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    bool isAdmin,
    bool isDevModeActive,
    dynamic user,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
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
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'م',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryAmber,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Profile
          ListTile(
            leading: const Icon(Icons.person, color: AppTheme.primaryAmber),
            title: const Text(ArabicLabels.profile),
            onTap: () {
              Navigator.pop(context);
              context.go('/profile');
            },
          ),

          // Admin-only sections
          if (isAdmin) ...[
            const Divider(),
            const ListTile(
              leading: Icon(Icons.admin_panel_settings,
                  color: AppTheme.primaryAmber),
              title: Text('مشرف النظام'),
              subtitle: Text('لوحة تحكم المشرف'),
            ),
            _adminTile(context, 'لوحة التحكم', Icons.dashboard, '/admin-home'),
            _adminTile(
                context, 'إدارة المستخدمين', Icons.people, '/admin/users'),
            _adminTile(context, 'مراجعة الشهادات', Icons.verified,
                '/admin/credentials'),
            _adminTile(context, 'العمليات الفاشلة', Icons.warning,
                '/admin/failed-ops'),
            _adminTile(
                context, 'أكواد الخصم', Icons.discount, '/admin/promo-codes'),
            _adminTile(
                context, 'إعدادات النظام', Icons.settings, '/admin/settings'),
            _adminTile(context, 'وضع التطوير', Icons.developer_mode,
                '/admin/dev-mode'),
            _adminTile(
                context, 'إشعارات جماعية', Icons.campaign, '/admin/broadcast'),
            _adminTile(context, 'القفلات النشطة', Icons.lock_clock,
                '/admin/slot-locks'),
            _adminTile(
                context, 'أحداث الدفع', Icons.payment, '/admin/payment-events'),
            _adminTile(
                context, 'العمولات', Icons.analytics, '/admin/commissions'),
            if (isDevModeActive)
              _adminTile(
                  context, 'DEV MODE', Icons.bug_report, '/admin/dev-mode',
                  color: Colors.red),
          ],

          // Mohaffez-only sections
          if (isMohaffez) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.verified_user, color: Colors.purple),
              title: const Text('الشهادات'),
              onTap: () {
                Navigator.pop(context);
                context.go('/credentials');
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blue),
              title: const Text('إدارة الأوقات'),
              onTap: () {
                Navigator.pop(context);
                context.go('/availability');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.orange),
              title: const Text('مدفوعات بانتظار التأكيد'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DirectPaymentConfirmationsScreen(),
                  ),
                );
              },
            ),
          ],

          const Divider(),

          // Settings - COMPLETED TODO
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text(ArabicLabels.settings),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),

          // Privacy - COMPLETED TODO
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.grey),
            title: const Text(ArabicLabels.privacy),
            onTap: () {
              Navigator.pop(context);
              context.go('/privacy-settings');
            },
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    bool isAdmin,
    int currentIndex,
  ) {
    if (isAdmin) {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(index);
          switch (index) {
            case 0:
              context.go('/admin-home');
              break;
            case 1:
              context.go('/admin/users');
              break;
            case 2:
              context.go('/admin/payment-events');
              break;
            case 3:
              context.go('/admin/settings');
              break;
          }
        },
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'لوحة التحكم'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'المستخدمون'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payment), label: 'المدفوعات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      );
    } else if (isMohaffez) {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(index);
          switch (index) {
            case 0:
              context.go('/mohaffez-home');
              break;
            case 1:
              context.go('/notifications');
              break;
            case 2:
              context.go('/profile');
              break;
          }
        },
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: ArabicLabels.home),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: ArabicLabels.notifications),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: ArabicLabels.profile),
        ],
      );
    } else {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).setIndex(index);
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/nearby');
              break;
            case 2:
              context.go('/notifications');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: ArabicLabels.home),
          BottomNavigationBarItem(
              icon: Icon(Icons.search), label: ArabicLabels.search),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: ArabicLabels.notifications),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: ArabicLabels.profile),
        ],
      );
    }
  }

  Widget _adminTile(
      BuildContext context, String title, IconData icon, String route,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.primaryAmber),
      title: Text(title, style: TextStyle(color: color)),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
