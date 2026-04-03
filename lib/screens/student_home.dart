import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/payment_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../services/app_version_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/error_widgets.dart';

class StudentHome extends ConsumerStatefulWidget {
  const StudentHome({super.key});

  @override
  ConsumerState<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends ConsumerState<StudentHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppVersionService.checkOnStartup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StudentHomeContent(studentId: user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

class StudentHomeContent extends ConsumerWidget {
  final String studentId;

  const StudentHomeContent({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: RefreshIndicator(
          displacement: 20,
          color: primary,
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            ref.invalidate(studentSessionsFirstPageProvider(studentId));
            ref.invalidate(studentRequestsFirstPageProvider(studentId));
            ref.invalidate(activeSubscriptionsProvider(studentId));
            await ref
                .read(studentSessionsFirstPageProvider(studentId).future)
                .catchError((_) => <Map<String, dynamic>>[]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 248,
                pinned: true,
                elevation: 0,
                backgroundColor: primary,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _DashboardHeader(
                    name: user?.name ?? 'الطالب',
                    photoUrl: user?.photoUrl,
                    roleLabel: 'لوحة الطالب',
                    subtitle: _greetingMessage(),
                    dateText: DateFormat('EEEE، d MMMM', 'ar')
                        .format(DateTime.now()),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    QuickStatsSection(studentId: studentId),
                    const SizedBox(height: 24),
                    QuickActionsSection(studentId: studentId),
                    const SizedBox(height: 24),
                    RecentAssignmentsSection(studentId: studentId),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير، جاهز لرحلة الحفظ اليوم؟';
    if (hour < 17) return 'يوم جميل لمراجعة ما أنجزته .';
    return 'مساء هادئ لمتابعة الجلسات والواجبات.';
  }
}

class QuickStatsSection extends ConsumerWidget {
  final String studentId;

  const QuickStatsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));
    final requestsAsync = ref.watch(studentRequestsFirstPageProvider(studentId));
    final subscriptionsAsync = ref.watch(activeSubscriptionsProvider(studentId));
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeader(
          title: 'إحصائيات سريعة',
          subtitle: 'ملخص سريع لنشاطك الحالي',
          trailing: _SectionChip(
            label: 'محدث الآن',
            color: primary,
            icon: Icons.bolt_rounded,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            final stats = [
              _DashboardStatData(
                title: 'إجمالي الجلسات',
                subtitle: 'الجلسات المكتملة والمقبولة',
                value: sessionsAsync.when(
                  data: (sessions) => sessions
                      .where((session) {
                        final status =
                            (session['status'] as String?)?.toLowerCase();
                        return status == 'accepted' || status == 'completed';
                      })
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                icon: Icons.calendar_today,
                accent: primary,
                onTap: () => context.go('/my-sessions'),
              ),
              _DashboardStatData(
                title: 'الطلبات النشطة',
                subtitle: 'طلبات بانتظار المتابعة',
                value: requestsAsync.when(
                  data: (requests) => requests
                      .where((request) {
                        final status =
                            (request['status'] as String?)?.toLowerCase();
                        return status == 'pending' ||
                            status == 'awaitingpayment';
                      })
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                icon: Icons.history_edu,
                accent: const Color(0xFFE67E22),
                onTap: () => context.go('/requests'),
              ),
              _DashboardStatData(
                title: 'الباقات النشطة',
                subtitle: 'اشتراكات متاحة للحجز',
                value: subscriptionsAsync.when(
                  data: (subscriptions) => subscriptions.length.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                icon: Icons.workspace_premium,
                accent: const Color(0xFF2E8B57),
                onTap: () => context.push('/active-subscriptions'),
              ),
              _DashboardStatData(
                title: 'الجلسات المتبقية',
                subtitle: 'إجمالي الرصيد المتبقي',
                value: subscriptionsAsync.when(
                  data: (subscriptions) => subscriptions
                      .fold<int>(
                        0,
                        (sum, subscription) =>
                            sum + subscription.remainingSessions,
                      )
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                icon: Icons.stars_rounded,
                accent: const Color(0xFF7A5AF8),
                onTap: () => context.push('/active-subscriptions'),
              ),
            ];

            return GridView.builder(
              itemCount: stats.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isNarrow ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isNarrow ? 1.65 : 0.95,
              ),
              itemBuilder: (context, index) {
                final stat = stats[index];
                return _DashboardStatCard(data: stat);
              },
            );
          },
        ),
      ],
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  final String studentId;

  const QuickActionsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final actions = [
      _DashboardActionData(
        title: 'احجز جلسة',
        subtitle: 'ابحث عن محفظ مناسب وابدأ الحجز',
        icon: Icons.calendar_today,
        accent: primary,
        height: 184,
        onTap: () => context.go('/nearby'),
      ),
      _DashboardActionData(
        title: 'جدولي الدراسي',
        subtitle: 'راجع مواعيدك القادمة بسرعة',
        icon: Icons.schedule,
        accent: const Color(0xFF0F766E),
        height: 162,
        onTap: () => context.go('/my-schedule'),
      ),
      _DashboardActionData(
        title: 'جلساتي',
        subtitle: 'تابع الجلسات المكتملة والقادمة',
        icon: Icons.history_edu,
        accent: const Color(0xFF2E8B57),
        height: 162,
        onTap: () => context.go('/my-sessions'),
      ),
      _DashboardActionData(
        title: 'واجباتي',
        subtitle: 'آخر التكليفات من محفظك',
        icon: Icons.assignment_rounded,
        accent: const Color(0xFFE67E22),
        height: 184,
        onTap: () => context.go('/assignments'),
      ),
      _DashboardActionData(
        title: 'طلباتي',
        subtitle: 'راجع حالة الطلبات والمدفوعات',
        icon: Icons.pending_actions_rounded,
        accent: const Color(0xFF7A5AF8),
        height: 184,
        onTap: () => context.go('/requests'),
      ),
      _DashboardActionData(
        title: 'اشتراكاتي',
        subtitle: 'إدارة الباقات والجلسات المتبقية',
        icon: Icons.account_balance_wallet,
        accent: const Color(0xFFB7791F),
        height: 162,
        onTap: () => context.push('/active-subscriptions'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeader(
          title: 'الإجراءات الرئيسية',
          subtitle: 'كل ما تحتاجه في مكان واحد',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Column(
                children: actions
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DashboardActionCard(data: action),
                      ),
                    )
                    .toList(),
              );
            }

            final columns = <List<_DashboardActionData>>[
              <_DashboardActionData>[],
              <_DashboardActionData>[],
            ];

            for (var index = 0; index < actions.length; index++) {
              columns[index % 2].add(actions[index]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: columns[0]
                        .map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DashboardActionCard(data: action),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: columns[1]
                        .map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DashboardActionCard(data: action),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class RecentAssignmentsSection extends ConsumerWidget {
  final String studentId;

  const RecentAssignmentsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardSectionHeader(
          title: 'آخر الواجبات',
          subtitle: 'مراجعة سريعة لأحدث التكليفات',
          trailing: TextButton.icon(
            onPressed: () => context.go('/assignments'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            label: const Text('عرض الكل'),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 14),
        sessionsAsync.when(
          data: (sessions) {
            final assignments = sessions
                .where(
                  (session) =>
                      ((session['hifzAssignment'] as String?) ?? '').isNotEmpty ||
                      ((session['murajaAssignment'] as String?) ?? '')
                          .isNotEmpty,
                )
                .take(3)
                .toList();

            if (assignments.isEmpty) {
              return _DashboardEmptyCard(
                icon: Icons.assignment_late_outlined,
                title: 'لا توجد واجبات جديدة حالياً',
                subtitle: 'عند إضافة تكليف جديد سيظهر هنا مباشرة.',
                accent: primary,
              );
            }

            return Column(
              children: assignments.map((session) {
                final mohaffezName =
                    (session['mohaffezName'] as String?) ?? 'محفظ';
                final hifz = (session['hifzAssignment'] as String?) ?? '';
                final muraja = (session['murajaAssignment'] as String?) ?? '';
                final sessionDateRaw = session['sessionDate'];
                final sessionDate = sessionDateRaw is Timestamp
                    ? sessionDateRaw.toDate()
                    : sessionDateRaw as DateTime?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DashboardAssignmentCard(
                    mohaffezName: mohaffezName,
                    hifz: hifz,
                    muraja: muraja,
                    sessionDate: sessionDate,
                    onTap: () => context.go('/assignments'),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _DashboardEmptyCard(
            icon: Icons.error_outline,
            title: 'تعذر تحميل الواجبات',
            subtitle: 'حاول التحديث مرة أخرى.',
            accent: AppThemeConstants.error,
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String roleLabel;
  final String subtitle;
  final String dateText;

  const _DashboardHeader({
    required this.name,
    required this.photoUrl,
    required this.roleLabel,
    required this.subtitle,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            AppThemeConstants.midTeal,
            AppThemeConstants.deepTeal,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileAvatar(
                    name: name,
                    photoUrl: photoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.dashboard_customize_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'مرحباً، $name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateText,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'رتب أولوياتك اليوم.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.84),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _DashboardSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatData {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _DashboardStatData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _DashboardStatCard extends StatelessWidget {
  final _DashboardStatData data;

  const _DashboardStatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: data.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.accent.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(data.icon, color: data.accent),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: data.accent.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: data.accent,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppThemeConstants.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeConstants.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  const _DashboardActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.height,
    required this.onTap,
  });
}

class _DashboardActionCard extends StatelessWidget {
  final _DashboardActionData data;

  const _DashboardActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: data.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  data.accent.withValues(alpha: 0.18),
                  data.accent.withValues(alpha: 0.08),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(color: data.accent.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(data.icon, color: data.accent),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: data.accent,
                      ),
                    ],
                  ),
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppThemeConstants.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardAssignmentCard extends StatelessWidget {
  final String mohaffezName;
  final String hifz;
  final String muraja;
  final DateTime? sessionDate;
  final VoidCallback onTap;

  const _DashboardAssignmentCard({
    required this.mohaffezName,
    required this.hifz,
    required this.muraja,
    required this.sessionDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person_rounded, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mohaffezName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sessionDate == null
                                ? 'تاريخ غير محدد'
                                : DateFormat('d MMMM yyyy', 'ar')
                                    .format(sessionDate!),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  if (hifz.isNotEmpty)
                    AssignmentRow(
                      label: 'حفظ',
                      text: hifz,
                      color: primary,
                    ),
                  if (muraja.isNotEmpty)
                    AssignmentRow(
                      label: 'مراجعة',
                      text: muraja,
                      color: const Color(0xFF2E8B57),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _DashboardEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppThemeConstants.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppThemeConstants.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _ProfileAvatar({
    required this.name,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initials = trimmedName.isEmpty ? 'ط' : trimmedName.substring(0, 1);

    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(photoUrl!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

class AssignmentRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const AssignmentRow({
    super.key,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.textPrimary,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
