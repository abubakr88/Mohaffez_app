// lib/screens/active_subscriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/subscription_model.dart';
import '../models/pricing_plan_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/user_provider.dart';
import '../shared/theme/app_theme_constants.dart';

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
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppThemeConstants.backgroundLight,
            appBar: AppBar(
              title: const Text('باقاتي'),
              backgroundColor: AppThemeConstants.primaryAmber,
              foregroundColor: AppThemeConstants.surfaceWhite,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppThemeConstants.surfaceWhite,
                labelColor: AppThemeConstants.surfaceWhite,
                unselectedLabelColor:
                    AppThemeConstants.surfaceWhite.withValues(alpha: 0.6),
                tabs: _kTabs
                    .map((t) => Tab(text: t.label))
                    .toList(),
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
  const _SubscriptionTabView(
      {required this.studentId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(
      filteredSubscriptionsProvider(
          (studentId: studentId, status: status)),
    );

    return subsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (subs) {
        if (subs.isEmpty) return _EmptyState(status: status);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: subs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              _SubscriptionCard(sub: subs[i]),
        );
      },
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel sub;
  const _SubscriptionCard({required this.sub});

  Color get _progressColor {
    final p = sub.progressPercentage;
    if (p >= 0.5) return AppThemeConstants.accentGreen;
    if (p >= 0.2) return AppThemeConstants.warning;
    return AppThemeConstants.error;
  }

  // FIX: Helper method to get plan type label
  String _planTypeLabel(PlanType type) {
    switch (type) {
      case PlanType.bundle:
        return 'باقة حلقات';
      case PlanType.subscription:
        return 'اشتراك شهري';
      case PlanType.single:
        return 'جلسة مفردة';
    }
  }

  String _expiryLabel() {
    if (sub.expiryDate == null) return 'بدون تاريخ انتهاء';
    final days = sub.expiryDate!.difference(DateTime.now()).inDays;
    if (days < 0) return 'منتهية الصلاحية';
    if (days == 0) return '⚠️ تنتهي اليوم!';
    if (days <= 14) return '⚠️ تنتهي خلال $days يوماً';
    final d = sub.expiryDate!;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppThemeConstants.surfaceWhite,
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
                      AppThemeConstants.primaryAmber.withValues(alpha: 0.15),
                  child: Text(
                    sub.mohaffezName.isNotEmpty
                        ? sub.mohaffezName[0]
                        : '؟',
                    style: const TextStyle(
                      color: AppThemeConstants.primaryAmber,
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
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
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
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_progressColor),
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
                    color: sub.expiryDate != null &&
                            sub.expiryDate!
                                    .difference(DateTime.now())
                                    .inDays <=
                                14
                        ? AppThemeConstants.error
                        : Colors.grey.shade500,
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
                  onPressed: () => context.push(
                    '/mohaffez/${sub.mohaffezId}',
                  ),
                  icon: const Icon(Icons.book_online_outlined, size: 18),
                  label: const Text('احجز جلسة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primaryAmber,
                    foregroundColor: AppThemeConstants.surfaceWhite,
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

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.card_membership_outlined : Icons.history,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'لا توجد باقات نشطة' : 'لا يوجد سجل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'ابحث عن محفظ واحجز باقتك الأولى',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/nearby'),
                icon: const Icon(Icons.search),
                label: const Text('ابحث عن محفظ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primaryAmber,
                  foregroundColor: AppThemeConstants.surfaceWhite,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
