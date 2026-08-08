// lib/screens/active_subscriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

// Tab config
const _kTabs = [
  (label: 'النشطة', status: 'active'),
  (label: 'المستنفدة', status: 'depleted'),
  (label: 'المنتهية', status: 'expired'),
];

class ActiveSubscriptionsScreen extends ConsumerStatefulWidget {
  const ActiveSubscriptionsScreen({super.key});

  @override
  ConsumerState<ActiveSubscriptionsScreen> createState() =>
      _ActiveSubscriptionsScreenState();
}

class _ActiveSubscriptionsScreenState
    extends ConsumerState<ActiveSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const Scaffold(
          body: Center(
              child:
                  Text('حدث خطأ في تحميل البيانات. يرجى المحاولة مرة أخرى.'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.go('/login'));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppThemeConstants.background,
            appBar: AppBar(
              title: const Text('باقاتي'),
              backgroundColor: AppThemeConstants.primary,
              foregroundColor: AppThemeConstants.surface,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppThemeConstants.surface,
                labelColor: AppThemeConstants.surface,
                unselectedLabelColor:
                    AppThemeConstants.surface.withValues(alpha: 0.6),
                tabs: _kTabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: _kTabs
                  .map((t) => _SubscriptionTabView(
                        studentId: user.uid,
                        status: t.status,
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _SubscriptionTabView extends ConsumerWidget {
  final String studentId;
  final String status;
  const _SubscriptionTabView({required this.studentId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(
      filteredSubscriptionsProvider((studentId: studentId, status: status)),
    );

    Future<void> onRefresh() async {
      ref.invalidate(filteredSubscriptionsProvider(
          (studentId: studentId, status: status)));
      await ref.read(
          filteredSubscriptionsProvider((studentId: studentId, status: status))
              .future);
    }

    return subsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
          child: Text('حدث خطأ في تحميل الاشتراكات. يرجى المحاولة مرة أخرى.')),
      data: (subs) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: subs.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _EmptyState(status: status),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: subs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _SubscriptionCard(sub: subs[i]),
                ),
        );
      },
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  final SubscriptionModel sub;
  const _SubscriptionCard({required this.sub});

  Color get _progressColor {
    final p = sub.progressPercentage;
    if (p >= 0.5) return AppThemeConstants.secondary;
    if (p >= 0.2) return AppThemeConstants.warning;
    return AppThemeConstants.error;
  }

  String _planTypeLabel(PlanType type) {
    switch (type) {
      case PlanType.bundle:
        return 'باقة حلقات';
      case PlanType.single:
        return 'جلسة مفردة';
    }
  }

  int? get _expiryDays {
    if (sub.expiryDate == null) return null;
    return sub.expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get _isExpiringSoon {
    final days = _expiryDays;
    return days != null && days >= 0 && days <= 14;
  }

  String _expiryLabel() {
    if (sub.expiryDate == null) return 'بدون تاريخ انتهاء';
    final days = _expiryDays!;
    if (days < 0) return 'منتهية الصلاحية';
    if (days == 0) return '⚠️ تنتهي اليوم!';
    if (days <= 14) return '⚠️ تنتهي خلال $days يوماً';
    return DateFormat('d MMMM y', 'ar').format(sub.expiryDate!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: AppThemeConstants.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
        side: BorderSide(
          color: _progressColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + session type
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppThemeConstants.primary.withValues(alpha: 0.15),
                  child: Text(
                    _getAvatarInitial(sub.mohaffezName),
                    style: const TextStyle(
                      color: AppThemeConstants.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.mohaffezName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.textPrimary,
                        ),
                      ),
                      Text(
                        '${sub.planTitle} · ${_planTypeLabel(sub.planType)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppThemeConstants.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: sub.progressPercentage,
                backgroundColor: AppThemeConstants.divider,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sub.remainingSessions} متبقي من ${sub.totalSessions}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _progressColor,
                  ),
                ),
                Text(
                  '📅 ${_expiryLabel()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isExpiringSoon
                        ? AppThemeConstants.error
                        : AppThemeConstants.textSecondary,
                  ),
                ),
              ],
            ),
            // "احجز جلسة" button — only for active bundles
            if (sub.canBookSession) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final subscriptionId = sub.id;
                    if (subscriptionId == null || subscriptionId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تعذر تحديد الباقة. يرجى تحديث الصفحة والمحاولة مرة أخرى.'),
                          backgroundColor: AppThemeConstants.error,
                        ),
                      );
                      return;
                    }
                    ref.read(bookingFlowProvider.notifier).reset();
                    await context.push(
                      '/mohaffez/${sub.mohaffezId}?subscriptionId=${Uri.encodeQueryComponent(subscriptionId)}',
                    );
                    if (context.mounted) {
                      ref.read(bookingFlowProvider.notifier).reset();
                    }
                  },
                  icon: const Icon(Icons.book_online_outlined, size: 18),
                  label: const Text('احجز جلسة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: AppThemeConstants.surface,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppThemeConstants.borderRadiusMd,
                    ),
                  ),
                ),
              ),
            ],
          ],
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

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final isDepleted = status == 'depleted';
    final isExpired = status == 'expired';

    String getTitle() {
      if (isActive) return 'لا توجد باقات نشطة';
      if (isDepleted) return 'لا توجد باقات مستنفدة';
      if (isExpired) return 'لا توجد باقات منتهية';
      return 'لا يوجد سجل';
    }

    String getSubtitle() {
      if (isActive) return 'ابحث عن محفظ واحجز باقتك الأولى';
      if (isDepleted) return 'يمكنك تجديد باقتك أو حجز باقة جديدة';
      if (isExpired) return 'تم انتهاء صلاحية جميع باقاتك السابقة';
      return '';
    }

    IconData getIcon() {
      if (isActive) return Icons.card_membership_outlined;
      if (isDepleted) return Icons.hourglass_empty;
      if (isExpired) return Icons.event_busy;
      return Icons.history;
    }

    String getButtonLabel() {
      return 'ابحث عن محفظ';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              getIcon(),
              size: 64,
              color: AppThemeConstants.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              getTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.grey600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              getSubtitle(),
              style: const TextStyle(
                  fontSize: 14, color: AppThemeConstants.grey400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/nearby'),
              icon: Icon(isActive ? Icons.search : Icons.refresh),
              label: Text(getButtonLabel()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
