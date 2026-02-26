import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_provider.dart';
import '../providers/system_config_provider.dart';
import '../services/app_version_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppVersionService.checkOnStartup(context);
      }
    });
  }

  Stream<int> _countStream(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .asyncMap((_) async {
      final agg =
          await FirebaseFirestore.instance.collection(collection).count().get();
      return agg.count ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCredentialsProvider);
    final failed = ref.watch(failedOperationsProvider);
    final config = ref.watch(systemConfigProvider).value;
    final devActive = ref.watch(isDevModeActiveProvider);

    final cards = <Widget>[
      _statCard(
          ArabicLabels.totalUsers,
          Icons.people,
          StreamBuilder<int>(
            stream: _countStream('users'),
            builder: (_, s) => Text('${s.data ?? 0}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          )),
      _statCard(
          ArabicLabels.totalSessions,
          Icons.menu_book,
          StreamBuilder<int>(
            stream: _countStream('hafizSessions'),
            builder: (_, s) => Text('${s.data ?? 0}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          )),
      _statCard(
          ArabicLabels.pendingVerification,
          Icons.verified_user,
          pending.when(
            data: (v) => Text('${v.length}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('-'),
          )),
      _statCard(
          ArabicLabels.failedOperationsCount,
          Icons.error_outline,
          failed.when(
            data: (v) => Text('${v.length}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('-'),
          )),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(ArabicLabels.adminDashboard),
          actions: [
            if (devActive)
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: AppThemeConstants.spaceSm),
                child: Chip(label: Text('DEV')),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          child: Column(
            children: [
              if (config?.maintenanceMode == true)
                Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.only(bottom: AppThemeConstants.spaceMd),
                  padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warning.withValues(alpha: 0.2),
                    borderRadius: AppThemeConstants.borderRadiusMd,
                  ),
                  child: Text(
                      '${ArabicLabels.maintenanceModeActive} ${config?.maintenanceMessage ?? ''}'),
                ),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppThemeConstants.spaceMd,
                mainAxisSpacing: AppThemeConstants.spaceMd,
                childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: cards,
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
              Expanded(
                child: ListView(
                  children: const [
                    _AdminNavTile(
                        title: ArabicLabels.manageUsers,
                        icon: Icons.people,
                        routeName: 'admin-users'),
                    _AdminNavTile(
                        title: ArabicLabels.teacherCredentials,
                        icon: Icons.verified,
                        routeName: 'admin-credentials'),
                    _AdminNavTile(
                        title: ArabicLabels.failedOperations,
                        icon: Icons.warning,
                        routeName: 'admin-failed-ops'),
                    _AdminNavTile(
                        title: ArabicLabels.promoCodes,
                        icon: Icons.discount,
                        routeName: 'admin-promo-codes'),
                    _AdminNavTile(
                        title: ArabicLabels.systemSettings,
                        icon: Icons.settings,
                        routeName: 'admin-settings'),
                    _AdminNavTile(
                        title: ArabicLabels.devMode,
                        icon: Icons.developer_mode,
                        routeName: 'admin-dev-mode'),
                    _AdminNavTile(
                        title: ArabicLabels.broadcastNotifications,
                        icon: Icons.campaign,
                        routeName: 'admin-broadcast'),
                    _AdminNavTile(
                        title: ArabicLabels.slotLocksManagement,
                        icon: Icons.lock_clock,
                        routeName: 'admin-slot-locks'),
                    _AdminNavTile(
                        title: ArabicLabels.paymentEvents,
                        icon: Icons.payment,
                        routeName: 'admin-payment-events'),
                    _AdminNavTile(
                        title: ArabicLabels.commissionsBoard,
                        icon: Icons.analytics,
                        routeName: 'admin-commissions'),
                    _AdminNavTile(
                        title: ArabicLabels.operationsLog,
                        icon: Icons.history,
                        routeName: 'admin-audit-log'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, IconData icon, Widget value) {
    return Card(
      color: AppThemeConstants.surfaceWhite,
      child: Padding(
        padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppThemeConstants.primaryAmber),
            const SizedBox(height: AppThemeConstants.spaceSm),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppThemeConstants.spaceSm),
            value,
          ],
        ),
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String routeName;

  const _AdminNavTile({
    required this.title,
    required this.icon,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppThemeConstants.primaryAmber),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => context.pushNamed(routeName),
    );
  }
}
