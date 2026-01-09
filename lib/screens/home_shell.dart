import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'student_home.dart';
import 'mohaffez_home.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'nearby_mohaffez_screen.dart';
import 'auth_screen.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notification_provider.dart';
import '../services/cache_service.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const AuthScreen();
        }
        return _AuthenticatedShell(user: user);
      },
      loading: () => _LoadingScreen(),
      error: (error, stackTrace) => _ErrorScreen(
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
    );
  }
}

class _AuthenticatedShell extends ConsumerWidget {
  final user;

  const _AuthenticatedShell({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final isMohaffez = user.role == 'mohaffez';

    final screens = isMohaffez
        ? const [
            MohaffezHome(),
            NotificationsScreen(),
            ProfileScreen(),
          ]
        : const [
            StudentHome(),
            NearbyMohaffezScreen(),
            NotificationsScreen(),
            ProfileScreen(),
          ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(context, ref, isMohaffez, currentIndex),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(ref, isMohaffez, currentIndex),
        drawer: _buildDrawer(context, ref),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    int currentIndex,
  ) {
    String getTitle() {
      if (isMohaffez) {
        switch (currentIndex) {
          case 0:
            return 'لوحة المحفظ';
          case 1:
            return 'الإشعارات';
          case 2:
            return 'الملف الشخصي';
          default:
            return 'محفظي القريب';
        }
      } else {
        switch (currentIndex) {
          case 0:
            return 'الرئيسية';
          case 1:
            return 'ابحث عن محفظ';
          case 2:
            return 'الإشعارات';
          case 3:
            return 'الملف الشخصي';
          default:
            return 'محفظي القريب';
        }
      }
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
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
                      color: Colors.black.withOpacity(0.2),
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
          actions: [
            // Notification badge
            if (currentIndex != (isMohaffez ? 1 : 2)) _buildNotificationBadge(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          tooltip: 'الإشعارات',
          onPressed: () {
            final isMohaffez = user.role == 'mohaffez';
            ref.read(bottomNavIndexProvider.notifier).setIndex(isMohaffez ? 1 : 2);
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
  }

  Widget _buildBottomNavBar(WidgetRef ref, bool isMohaffez, int currentIndex) {
    if (isMohaffez) {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(bottomNavIndexProvider.notifier).setIndex(index),
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      );
    } else {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(bottomNavIndexProvider.notifier).setIndex(index),
        selectedItemColor: AppTheme.primaryAmber,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'بحث',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف',
          ),
        ],
      );
    }
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role == 'mohaffez' ? 'محفظ' : 'طالب',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () async {
              await _logout(ref);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    await FirebaseAuth.instance.signOut();
    await CacheService.clearAll();
    // ref.invalidate(currentUserProvider);
    // ref.read(bottomNavIndexProvider.notifier).reset();
  }
}

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryAmber),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل بيانات المستخدم...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                'خطأ في تحميل البيانات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
