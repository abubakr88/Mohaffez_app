import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import 'student_home.dart';
import 'mohaffez_home.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'nearby_mohaffez_screen.dart';
import 'auth_screen.dart';
import '../shared/widgets/offline_banner.dart';
import '../services/cache_service.dart';
import '../shared/constants/app_theme.dart';

// Bottom nav index provider
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  User? user;
  String? role;
  String? name;
  bool loadingUser = true;
  double? userLat;
  double? userLng;

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      setState(() {
        user = null;
        role = null;
        name = null;
        loadingUser = false;
      });
      return;
    }

    // Fast: Load from cache first for instant UI
    final cachedRole = CacheService.getUserRole();
    final cachedName = CacheService.getUserName();
    final cachedLocation = CacheService.getLastLocation();

    if (cachedRole != null && cachedName != null) {
      setState(() {
        user = current;
        role = cachedRole;
        name = cachedName;
        if (cachedLocation != null) {
          userLat = cachedLocation.$1;
          userLng = cachedLocation.$2;
        }
        loadingUser = false;
      });
    }

    // Then fetch from Firestore to sync any updates
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .get();

      final data = doc.data();
      if (data != null) {
        setState(() {
          user = current;
          role = data['role'] as String?;
          name = data['name'] as String?;
          userLat = (data['addressLat'] as num?)?.toDouble() ?? 30.0444;
          userLng = (data['addressLng'] as num?)?.toDouble() ?? 31.2357;
          loadingUser = false;
        });

        // Update cache with fresh data
        if (role != null) await CacheService.saveUserRole(role!);
        if (name != null) await CacheService.saveUserName(name!);
        await CacheService.saveUserId(current.uid);
        if (userLat != null && userLng != null) {
          await CacheService.saveLastLocation(userLat!, userLng!);
        }
      }
    } catch (e) {
      // If offline and no cache, show loading state ended
      if (!mounted) return;
      setState(() {
        loadingUser = false;
      });
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await CacheService.clearAll();
    setState(() {
      user = null;
      role = null;
      name = null;
    });
    ref.read(bottomNavIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (loadingUser) {
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

    if (user == null) {
      return const AuthScreen();
    }

    final isMohaffez = role == 'mohaffez';
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // Define screens for bottom navigation
    final List<Widget> screens = isMohaffez
        ? [
            const MohaffezHome(),
            const NotificationsScreen(),
            const ProfileScreen(),
          ]
        : [
            const StudentHome(),
            const NearbyMohaffezScreen(),
            const NotificationsScreen(),
            const ProfileScreen(),
          ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(context, isMohaffez, currentIndex),
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
        bottomNavigationBar: _buildBottomNavBar(isMohaffez, currentIndex),
        drawer: buildDrawer(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isMohaffez,
    int currentIndex,
  ) {
    // Dynamic title based on current tab
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
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school,
                          color: AppTheme.primaryAmber, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Text(getTitle()),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Notification badge in app bar
            if (currentIndex != (isMohaffez ? 1 : 2))
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'الإشعارات',
                    onPressed: () {
                      ref.read(bottomNavIndexProvider.notifier).state =
                          isMohaffez ? 1 : 2;
                    },
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: user!.uid)
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data?.docs.length ?? 0;
                      if (unreadCount == 0) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
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
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(bool isMohaffez, int currentIndex) {
    if (isMohaffez) {
      // Mohaffez bottom nav: Home, Notifications, Profile
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
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
            label: 'الحساب',
          ),
        ],
      );
    } else {
      // Student bottom nav: Home, Search, Notifications, Profile
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
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
            label: 'الحساب',
          ),
        ],
      );
    }
  }

  Widget buildDrawer(BuildContext context) {
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
                  name ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role == 'mohaffez' ? 'محفظ' : 'طالب',
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
            onTap: () {
              logout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
