import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mohaffez_core/src/providers/admin_provider.dart';
import 'package:mohaffez_core/src/providers/system_config_provider.dart';
import '../../services/app_version_service.dart';
import '../../shared/theme/app_theme_constants.dart';
import 'package:mohaffez_core/src/utils/arabic_labels.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _pendingTeacherRequestsProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('status', isEqualTo: 'pending_approval')
      .where('role', isEqualTo: 'mohaffez')
      .snapshots()
      .map((s) => s.size);
});

final _totalUsersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final agg =
      await FirebaseFirestore.instance.collection('users').count().get();
  return agg.count ?? 0;
});

final _totalSessionsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final agg = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .count()
      .get();
  return agg.count ?? 0;
});

// ── Screen ─────────────────────────────────────────────────────────────────

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
      if (mounted) AppVersionService.checkOnStartup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCredentialsProvider);
    final failed = ref.watch(failedOperationsProvider);
    final pendingTeachers = ref.watch(_pendingTeacherRequestsProvider);
    final totalUsers = ref.watch(_totalUsersCountProvider);
    final totalSessions = ref.watch(_totalSessionsCountProvider);
    final config = ref.watch(systemConfigProvider).value;
    final devActive = ref.watch(isDevModeActiveProvider);

    final pendingCredCount = pending.valueOrNull?.length ?? 0;
    final failedCount = failed.valueOrNull?.length ?? 0;
    final teacherRequestCount = pendingTeachers.valueOrNull ?? 0;

    final adminUser = FirebaseAuth.instance.currentUser;
    final adminName = adminUser?.displayName ?? 'المدير';
    final initial =
        adminName.isNotEmpty ? adminName.trimLeft()[0] : 'م';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: CustomScrollView(
          slivers: [
            // ── Gradient App Bar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 156,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeConstants.deepTeal,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppThemeConstants.tealGradient,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppThemeConstants.spaceMd,
                        AppThemeConstants.spaceSm,
                        AppThemeConstants.spaceMd,
                        AppThemeConstants.spaceMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppThemeConstants.secondary
                                    .withValues(alpha: 0.35),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppThemeConstants.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppThemeConstants.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'مرحباً،',
                                      style: TextStyle(
                                          color: AppThemeConstants.onPrimary.withValues(alpha: 0.6), fontSize: 12),
                                    ),
                                    Text(
                                      adminName,
                                      style: const TextStyle(
                                        color: AppThemeConstants.onPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (devActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppThemeConstants.secondary
                                        .withValues(alpha: 0.25),
                                    borderRadius:
                                        AppThemeConstants.borderRadiusSm,
                                    border: Border.all(
                                        color: AppThemeConstants.secondary),
                                  ),
                                  child: const Text(
                                    'DEV',
                                    style: TextStyle(
                                      color: AppThemeConstants.secondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'لوحة تحكم المشرف',
                            style: TextStyle(
                                color: AppThemeConstants.onPrimary.withValues(alpha: 0.38),
                                fontSize: 11,
                                letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              title: const Text(
                'لوحة التحكم',
                style: TextStyle(
                    color: AppThemeConstants.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Maintenance banner
                  if (config?.maintenanceMode == true)
                    _MaintenanceBanner(
                        message: config?.maintenanceMessage),

                  // Attention alerts
                  if (teacherRequestCount > 0 || failedCount > 0)
                    _AttentionBanner(
                      teacherRequests: teacherRequestCount,
                      failedOps: failedCount,
                    ),

                  // ── Stats ───────────────────────────────────────────
                  const _SectionHeader(title: 'نظرة عامة'),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppThemeConstants.spaceSm,
                      mainAxisSpacing: AppThemeConstants.spaceSm,
                      childAspectRatio: 1.35,
                    ),
                    children: [
                      _StatCard(
                        title: 'طلبات المحفظين',
                        icon: Icons.how_to_reg_rounded,
                        accentColor: const Color(0xFF7C3AED),
                        valueWidget: Text(
                          '$teacherRequestCount',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      _StatCard(
                        title: 'إجمالي المستخدمين',
                        icon: Icons.people_rounded,
                        accentColor: AppThemeConstants.primary,
                        valueWidget: totalUsers.when(
                          data: (v) => Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.primary,
                            ),
                          ),
                          loading: () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text('—'),
                        ),
                      ),
                      _StatCard(
                        title: 'شهادات معلقة',
                        icon: Icons.verified_rounded,
                        accentColor: AppThemeConstants.secondary,
                        valueWidget: Text(
                          '$pendingCredCount',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.secondary,
                          ),
                        ),
                      ),
                      _StatCard(
                        title: 'إجمالي الجلسات',
                        icon: Icons.menu_book_rounded,
                        accentColor: const Color(0xFF0891B2),
                        valueWidget: totalSessions.when(
                          data: (v) => Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0891B2),
                            ),
                          ),
                          loading: () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text('—'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppThemeConstants.spaceLg),

                  // ── User Management Group ────────────────────────────
                  const _SectionHeader(title: 'إدارة المستخدمين'),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  _NavCard(
                    title: 'طلبات انضمام المحفظين',
                    subtitle: 'مراجعة وقبول أو رفض طلبات التحفيظ',
                    icon: Icons.how_to_reg_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    routeName: 'admin-teacher-requests',
                    badgeCount: teacherRequestCount,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.manageUsers,
                    subtitle: 'عرض وإدارة حسابات المستخدمين',
                    icon: Icons.manage_accounts_rounded,
                    iconColor: AppThemeConstants.primary,
                    routeName: 'admin-users',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  _NavCard(
                    title: ArabicLabels.teacherCredentials,
                    subtitle: 'مراجعة الشهادات والمؤهلات المرفوعة',
                    icon: Icons.verified_rounded,
                    iconColor: AppThemeConstants.secondary,
                    routeName: 'admin-credentials',
                    badgeCount: pendingCredCount,
                  ),

                  const SizedBox(height: AppThemeConstants.spaceLg),

                  // ── Finance Group ────────────────────────────────────
                  const _SectionHeader(title: 'المالية والمدفوعات'),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.paymentEvents,
                    subtitle: 'سجل المعاملات المالية',
                    icon: Icons.receipt_long_rounded,
                    iconColor: Color(0xFF059669),
                    routeName: 'admin-payment-events',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.commissionsBoard,
                    subtitle: 'لوحة تتبع عمولات المنصة',
                    icon: Icons.analytics_rounded,
                    iconColor: Color(0xFF0891B2),
                    routeName: 'admin-commissions',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: 'عمولات المحفظين',
                    subtitle: 'عرض عمولات كل محفظ',
                    icon: Icons.people_alt_rounded,
                    iconColor: Color(0xFF7C3AED),
                    routeName: 'admin-teacher-commissions',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: 'أرقام محافظ المنصة',
                    subtitle: 'إدارة حسابات وأرقام المحافظ',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: Color(0xFFD97706),
                    routeName: 'admin-wallet-numbers',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.promoCodes,
                    subtitle: 'إنشاء وإدارة أكواد الخصم',
                    icon: Icons.discount_rounded,
                    iconColor: Color(0xFFEC4899),
                    routeName: 'admin-promo-codes',
                  ),

                  const SizedBox(height: AppThemeConstants.spaceLg),

                  // ── System Group ─────────────────────────────────────
                  const _SectionHeader(title: 'النظام والإعدادات'),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.systemSettings,
                    subtitle: 'الإعدادات العامة وخيارات النظام',
                    icon: Icons.settings_rounded,
                    iconColor: AppThemeConstants.textSecondary,
                    routeName: 'admin-settings',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.broadcastNotifications,
                    subtitle: 'إرسال إشعارات جماعية للمستخدمين',
                    icon: Icons.campaign_rounded,
                    iconColor: Color(0xFFEA580C),
                    routeName: 'admin-broadcast',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.slotLocksManagement,
                    subtitle: 'إدارة الجلسات المحجوبة والمقفلة',
                    icon: Icons.lock_clock_rounded,
                    iconColor: AppThemeConstants.textSecondary,
                    routeName: 'admin-slot-locks',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  _NavCard(
                    title: ArabicLabels.failedOperations,
                    subtitle: 'العمليات الفاشلة التي تحتاج مراجعة',
                    icon: Icons.warning_rounded,
                    iconColor: AppThemeConstants.error,
                    routeName: 'admin-failed-ops',
                    badgeCount: failedCount,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.operationsLog,
                    subtitle: 'سجل عمليات الأدمن والتغييرات',
                    icon: Icons.history_rounded,
                    iconColor: AppThemeConstants.textSecondary,
                    routeName: 'admin-audit-log',
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  const _NavCard(
                    title: ArabicLabels.devMode,
                    subtitle: 'أدوات وخيارات المطور',
                    icon: Icons.developer_mode_rounded,
                    iconColor: AppThemeConstants.textMuted,
                    routeName: 'admin-dev-mode',
                  ),

                  const SizedBox(height: AppThemeConstants.space2xl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget valueWidget;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: AppThemeConstants.borderRadiusMd,
        border: Border(
          right: BorderSide(color: accentColor, width: 3),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppThemeConstants.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeConstants.spaceMd,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: AppThemeConstants.borderRadiusSm,
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 6),
          valueWidget,
          const SizedBox(height: 1),
          Text(
            title,
            style: AppThemeConstants.labelSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Nav Card ───────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String routeName;
  final int? badgeCount;

  const _NavCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.routeName,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount != null && badgeCount! > 0;

    return Material(
      color: AppThemeConstants.surface,
      borderRadius: AppThemeConstants.borderRadiusMd,
      child: InkWell(
        onTap: () => context.pushNamed(routeName),
        borderRadius: AppThemeConstants.borderRadiusMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(
              color: hasBadge
                  ? iconColor.withValues(alpha: 0.35)
                  : AppThemeConstants.divider,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppThemeConstants.shadow,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppThemeConstants.spaceMd,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppThemeConstants.borderRadiusSm,
                ),
                child: Icon(icon,
                    color: iconColor, size: AppThemeConstants.iconMd),
              ),
              const SizedBox(width: AppThemeConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppThemeConstants.titleSmall),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppThemeConstants.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppThemeConstants.spaceSm),
              if (hasBadge)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    color: AppThemeConstants.error,
                    borderRadius: AppThemeConstants.borderRadiusRound,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: AppThemeConstants.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_left,
                  color: AppThemeConstants.textMuted,
                  size: AppThemeConstants.iconMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: const BoxDecoration(
            color: AppThemeConstants.secondary,
            borderRadius: AppThemeConstants.borderRadiusRound,
          ),
        ),
        const SizedBox(width: AppThemeConstants.spaceSm),
        Text(title, style: AppThemeConstants.headlineSmall),
      ],
    );
  }
}

// ── Maintenance Banner ─────────────────────────────────────────────────────

class _MaintenanceBanner extends StatelessWidget {
  final String? message;

  const _MaintenanceBanner({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppThemeConstants.spaceMd),
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.warningBackground,
        borderRadius: AppThemeConstants.borderRadiusMd,
        border: Border.all(
            color: AppThemeConstants.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.engineering_rounded,
              color: AppThemeConstants.warning,
              size: AppThemeConstants.iconMd),
          const SizedBox(width: AppThemeConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  ArabicLabels.maintenanceModeActive,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.warning,
                    fontSize: 13,
                  ),
                ),
                if (message != null && message!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(message!,
                        style: AppThemeConstants.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attention Banner ───────────────────────────────────────────────────────

class _AttentionBanner extends StatelessWidget {
  final int teacherRequests;
  final int failedOps;

  const _AttentionBanner({
    required this.teacherRequests,
    required this.failedOps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppThemeConstants.spaceMd),
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.errorBackground,
        borderRadius: AppThemeConstants.borderRadiusMd,
        border: Border.all(
            color: AppThemeConstants.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: AppThemeConstants.error, size: 16),
              SizedBox(width: 6),
              Text(
                'يحتاج تدخلاً',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.error,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (teacherRequests > 0)
            _alertItem(
                '$teacherRequests طلب انضمام محفظ معلق',
                Icons.how_to_reg_rounded),
          if (failedOps > 0)
            _alertItem(
                '$failedOps عملية فاشلة تحتاج مراجعة',
                Icons.warning_rounded),
        ],
      ),
    );
  }

  Widget _alertItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppThemeConstants.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: AppThemeConstants.error),
            ),
          ),
        ],
      ),
    );
  }
}
