import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/request_status.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../services/app_version_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/error_widgets.dart';
import '../utils/arabic_labels.dart';

class MohaffezHome extends ConsumerStatefulWidget {
  const MohaffezHome({super.key});

  @override
  ConsumerState<MohaffezHome> createState() => _MohaffezHomeState();
}

class _MohaffezHomeState extends ConsumerState<MohaffezHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppVersionService.checkOnStartup(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('لم يتم تسجيل الدخول')),
          );
        }

        return MohaffezHomeContent(mohaffezId: user.uid);
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

class MohaffezHomeContent extends ConsumerWidget {
  final String mohaffezId;

  const MohaffezHomeContent({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final primary = Theme.of(context).primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: RefreshIndicator(
          color: primary,
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
            ref.invalidate(upcomingSessionsProvider(mohaffezId));
            ref.invalidate(acceptedSessionsCountProvider(mohaffezId));
            await ref
                .read(upcomingSessionsProvider(mohaffezId).future)
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
                  background: _TeacherHeader(
                    name: user?.name ?? 'المحفظ',
                    photoUrl: user?.photoUrl,
                    subtitle: _teacherGreeting(),
                    dateText: DateFormat('EEEE، d MMMM', 'ar')
                        .format(DateTime.now()),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    QuickStatsSection(mohaffezId: mohaffezId),
                    const SizedBox(height: 24),
                    QuickActionsSection(mohaffezId: mohaffezId),
                    const SizedBox(height: 24),
                    UpcomingSessionsSection(mohaffezId: mohaffezId),
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

  String _teacherGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'ابدأ يومك بمتابعة والجلسات القادمة.';
    if (hour < 17) return 'الوقت مناسب لتنظيم جدول الجلسات.';
    return 'راجع مخرجات اليوم .';
  }
}

class QuickStatsSection extends ConsumerWidget {
  final String mohaffezId;

  const QuickStatsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(RequestStatus.teacherInbox.isNotEmpty);
    final upcomingSessions = ref.watch(upcomingSessionsProvider(mohaffezId));
    final pendingRequestsCount =
        ref.watch(pendingRequestsCountProvider(mohaffezId));
    final acceptedSessionsCount =
        ref.watch(acceptedSessionsCountProvider(mohaffezId));
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: 'إحصائياتك',
          subtitle: 'نظرة سريعة على نشاطك اليومي',
          trailing: _TeacherSectionChip(
            label: 'لوحة مباشرة',
            color: primary,
            icon: Icons.insights_rounded,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            final stats = [
              _TeacherStatData(
                icon: Icons.event_available,
                title: ArabicLabels.upcomingSessions,
                subtitle: 'الجلسات القادمة المسجلة',
                value: upcomingSessions.when(
                  data: (sessions) => sessions.length.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: primary,
                onTap: () {
                  ref.read(upcomingSessionsFilterProvider.notifier).state =
                      UpcomingFilter.all;
                  context.push('/upcoming-sessions?mohaffezId=$mohaffezId');
                },
              ),
              _TeacherStatData(
                icon: Icons.today_rounded,
                title: 'جلسات اليوم',
                subtitle: 'مواعيد اليوم فقط',
                value: upcomingSessions.when(
                  data: (sessions) {
                    final now = DateTime.now();
                    final todayCount = sessions.where((session) {
                      final date = session['sessionDate'] as DateTime?;
                      return date != null &&
                          date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
                    }).length;
                    return todayCount.toString();
                  },
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: const Color(0xFF2E8B57),
                onTap: () => context.go('/teacher-schedule'),
              ),
              _TeacherStatData(
                icon: Icons.pending_actions,
                title: ArabicLabels.pendingRequests,
                subtitle: 'طلبات بانتظار القرار',
                value: pendingRequestsCount.toString(),
                color: const Color(0xFFE67E22),
                onTap: () {
                  context.push('/pending-requests?mohaffezId=$mohaffezId');
                },
              ),
              _TeacherStatData(
                icon: Icons.verified_rounded,
                title: 'الجلسات المؤكدة',
                subtitle: 'إجمالي الجلسات المقبولة',
                value: acceptedSessionsCount.when(
                  data: (count) => count.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: const Color(0xFF7A5AF8),
                onTap: () {
                  ref.read(upcomingSessionsFilterProvider.notifier).state =
                      UpcomingFilter.all;
                  context.push('/upcoming-sessions?mohaffezId=$mohaffezId');
                },
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
              itemBuilder: (context, index) => StatCard(data: stats[index]),
            );
          },
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final _TeacherStatData data;

  const StatCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.color.withValues(alpha: 0.12)),
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
                      child: Icon(data.icon, color: data.color),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: data.color.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: data.color,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class QuickActionsSection extends StatelessWidget {
  final String mohaffezId;

  const QuickActionsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final actions = [
      _TeacherActionData(
        title: ArabicLabels.pendingRequests,
        subtitle: 'راجع الطلبات الجديدة بسرعة',
        icon: Icons.pending_actions,
        accent: const Color(0xFFE67E22),
        height: 184,
        onTap: () => context.push('/pending-requests?mohaffezId=$mohaffezId'),
      ),
      _TeacherActionData(
        title: 'الجدول',
        subtitle: 'تنظيم المواعيد الأسبوعية',
        icon: Icons.calendar_today,
        accent: primary,
        height: 162,
        onTap: () => context.go('/teacher-schedule'),
      ),
      _TeacherActionData(
        title: ArabicLabels.upcomingSessions,
        subtitle: 'كل الجلسات القادمة في شاشة واحدة',
        icon: Icons.history_edu,
        accent: const Color(0xFF2E8B57),
        height: 162,
        onTap: () => context.push('/upcoming-sessions?mohaffezId=$mohaffezId'),
      ),
      _TeacherActionData(
        title: 'إدارة الأسعار',
        subtitle: 'تحديث الخطط والأسعار بسهولة',
        icon: Icons.payments,
        accent: const Color(0xFF7A5AF8),
        height: 184,
        onTap: () => context.push('/pricing-management'),
      ),
      _TeacherActionData(
        title: 'مستحقات المنصة',
        subtitle: 'راجع العمولات والمدفوعات',
        icon: Icons.account_balance_wallet,
        accent: const Color(0xFFB7791F),
        height: 184,
        onTap: () => context.push('/mohaffez-commissions'),
      ),
      _TeacherActionData(
        title: 'طلابي',
        subtitle: 'الوصول السريع إلى قائمة الطلاب',
        icon: Icons.groups_rounded,
        accent: const Color(0xFF0F766E),
        height: 162,
        onTap: () => context.go('/my-students'),
      ),
      _TeacherActionData(
        title: 'الشهادات',
        subtitle: 'إدارة الملفات والشهادات المعتمدة',
        icon: Icons.verified_user,
        accent: const Color(0xFF2563EB),
        height: 162,
        onTap: () => context.push('/credentials'),
      ),
      _TeacherActionData(
        title: 'الأوقات المتاحة',
        subtitle: 'ضبط المواعيد المتاحة للحجز',
        icon: Icons.schedule,
        accent: const Color(0xFFDC2626),
        height: 184,
        onTap: () => context.push('/availability'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeSectionHeader(
          title: 'الإجراءات الرئيسية',
          subtitle: 'اختصارات سريعة لإدارة يومك',
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
                        child: ActionCard(data: action),
                      ),
                    )
                    .toList(),
              );
            }

            final columns = <List<_TeacherActionData>>[
              <_TeacherActionData>[],
              <_TeacherActionData>[],
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
                            child: ActionCard(data: action),
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
                            child: ActionCard(data: action),
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

class ActionCard extends StatelessWidget {
  final _TeacherActionData data;

  const ActionCard({
    super.key,
    required this.data,
  });

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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppThemeConstants.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 1,
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

class UpcomingSessionsSection extends ConsumerWidget {
  final String mohaffezId;

  const UpcomingSessionsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId));
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: ArabicLabels.upcomingSessions,
          subtitle: 'أقرب ثلاث جلسات تحتاج انتباهك',
          trailing: TextButton.icon(
            onPressed: () =>
                context.push('/upcoming-sessions?mohaffezId=$mohaffezId'),
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
            if (sessions.isEmpty) {
              return _TeacherEmptyCard(
                icon: Icons.event_busy,
                title: 'لا توجد جلسات قادمة',
                subtitle: 'سيظهر جدولك القادم هنا عند إضافة جلسات جديدة.',
                accent: primary,
              );
            }

            return Column(
              children: sessions.take(3).map((session) {
                final studentName = session['studentName'] as String? ??
                    ArabicLabels.notSpecified;
                final sessionDate = session['sessionDate'] as DateTime?;
                final timeSlot =
                    session['preferredTimeSlot'] as String? ?? '08:00';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UpcomingSessionCard(
                    studentName: studentName,
                    sessionDate: sessionDate,
                    timeSlot: timeSlot,
                    accent: primary,
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _TeacherEmptyCard(
            icon: Icons.error_outline,
            title: 'تعذر تحميل الجلسات',
            subtitle: 'حاول التحديث مرة أخرى.',
            accent: AppThemeConstants.error,
          ),
        ),
      ],
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String subtitle;
  final String dateText;

  const _TeacherHeader({
    required this.name,
    required this.photoUrl,
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
                  _ProfileAvatar(name: name, photoUrl: photoUrl),
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'لوحة المحفظ',
                                style: TextStyle(
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
                            'تابع الإحصائيات والاختصارات لتبقى يومك منظماً وواضحاً.',
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

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _HomeSectionHeader({
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

class _TeacherSectionChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _TeacherSectionChip({
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

class _TeacherStatData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _TeacherStatData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onTap,
  });
}

class _TeacherActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  const _TeacherActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.height,
    required this.onTap,
  });
}

class _UpcomingSessionCard extends StatelessWidget {
  final String studentName;
  final DateTime? sessionDate;
  final String timeSlot;
  final Color accent;

  const _UpcomingSessionCard({
    required this.studentName,
    required this.sessionDate,
    required this.timeSlot,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.school, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InfoPill(
                      icon: Icons.calendar_today,
                      text: sessionDate == null
                          ? ArabicLabels.notSpecified
                          : DateFormat('dd/MM/yyyy', 'ar').format(sessionDate!),
                    ),
                    _InfoPill(
                      icon: Icons.access_time,
                      text: timeSlot,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppThemeConstants.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppThemeConstants.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TeacherEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _TeacherEmptyCard({
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
    final initials = trimmedName.isEmpty ? 'م' : trimmedName.substring(0, 1);

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
