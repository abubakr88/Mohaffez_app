import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notification_provider_paginated.dart';

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(context, ref, isMohaffez, currentIndex, user.uid),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(context, ref, isMohaffez, currentIndex),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    int currentIndex,
    String userId,
  ) {
    String getTitle() {
      if (isMohaffez) {
        switch (currentIndex) {
          case 0:
            return 'الرئيسية';
          case 1:
            return 'الإشعارات';
          case 2:
            return 'الملف الشخصي';
          default:
            return 'محفظ';
        }
      } else {
        switch (currentIndex) {
          case 0:
            return 'الرئيسية';
          case 1:
            return 'البحث';
          case 2:
            return 'الإشعارات';
          case 3:
            return 'الملف الشخصي';
          default:
            return 'محفظ';
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
            if (currentIndex != (isMohaffez ? 1 : 2))
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
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider(userId));

    return unreadCountAsync.when(
      data: (unreadCount) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'الإشعارات',
              onPressed: () {
                ref.read(bottomNavIndexProvider.notifier).setIndex(isMohaffez ? 1 : 2);
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

  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    bool isMohaffez,
    int currentIndex,
  ) {
    if (isMohaffez) {
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'الإشعارات'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الملف الشخصي'),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'البحث'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'الإشعارات'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الملف الشخصي'),
        ],
      );
    }
  }
}
