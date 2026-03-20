// lib/screens/student_home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/subscription_model.dart';
import '../providers/payment_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../services/app_version_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/theme/theme_extensions.dart';
import '../shared/widgets/error_widgets.dart';

// ============================================================
// ROOT ENTRY POINT
// ============================================================
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

// ============================================================
// MAIN CONTENT
// ============================================================
class StudentHomeContent extends ConsumerWidget {
  final String studentId;
  const StudentHomeContent({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.backgroundLight,
        body: RefreshIndicator(
          displacement: 20,
          color: AppThemeConstants.primaryAmber,
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
              _buildAppBar(context, ref),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeCard(ref),
                    const SizedBox(height: 20),
                    QuickStatsSection(studentId: studentId),
                    Spacing.vLg,
                    // ── NEW: Bundle strip (hidden when empty) ──────────────
                    BundleStripSection(studentId: studentId),
                    // ── Quick Actions ──────────────────────────────────────
                    QuickActionsSection(studentId: studentId),
                    Spacing.vLg,
                    RecentAssignmentsSection(studentId: studentId),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── APP BAR ─────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final dateLabel =
        '${dayNames[now.weekday % 7]}، ${now.day} ${monthNames[now.month - 1]}';

    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppThemeConstants.primaryAmber,
      automaticallyImplyLeading: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppThemeConstants.primaryAmber,
                AppThemeConstants.primaryAmberLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Logo row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                        child: Image.asset(
                          'assets/images/icon.png',
                          height: 30,
                          width: 30,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'المحفظ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Date badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Decorative Quran verse hint
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'حافظوا على القرآن الكريم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'تتبّع جلساتك ومهامك بسهولة',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── WELCOME CARD ─────────────────────────────────────────────
  Widget _buildWelcomeCard(WidgetRef ref) {
    final hour = DateTime.now().hour;
    final String greeting;
    final IconData greetIcon;
    if (hour >= 5 && hour < 12) {
      greeting = 'صباح الخير 🌤';
      greetIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'مساء الخير ☀️';
      greetIcon = Icons.wb_twilight_outlined;
    } else if (hour >= 17 && hour < 21) {
      greeting = 'مساء النور 🌆';
      greetIcon = Icons.nights_stay_outlined;
    } else {
      greeting = 'تصبح على خير 🌙';
      greetIcon = Icons.bedtime_outlined;
    }

    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(currentUserProvider).value;
        final firstName = user?.name.split(' ').first ?? 'الطالب';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppThemeConstants.surfaceWhite,
            borderRadius: AppThemeConstants.borderRadiusXl,
            boxShadow: [
              BoxShadow(
                color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeConstants.primaryAmber,
                      AppThemeConstants.primaryAmberLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppThemeConstants.borderRadiusMd,
                ),
                child: Icon(greetIcon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'استمر في رحلتك مع القرآن الكريم ✨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Avatar circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppThemeConstants.primaryAmber,
                      AppThemeConstants.primaryAmberLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemeConstants.primaryAmber.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    firstName.isNotEmpty ? firstName[0] : '؟',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// QUICK STATS SECTION
// ============================================================
class QuickStatsSection extends ConsumerWidget {
  final String studentId;
  const QuickStatsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));
    final requestsAsync = ref.watch(studentRequestsFirstPageProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نظرة سريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.textPrimary,
          ),
        ),
        Spacing.vMd,
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.event_available_rounded,
                title: 'الجلسات المكتملة',
                value: sessionsAsync.when(
                  data: (sessions) => sessions
                      .where((s) {
                        final st = (s['status'] as String?)?.toLowerCase();
                        return st == 'accepted' || st == 'completed';
                      })
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: AppThemeConstants.accentGreen,
                onTap: () => context.go('/my-sessions'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.pending_actions_rounded,
                title: 'الطلبات النشطة',
                value: requestsAsync.when(
                  data: (requests) => requests
                      .where((r) {
                        final st = (r['status'] as String?)?.toLowerCase();
                        return st == 'pending' || st == 'awaitingpayment';
                      })
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: Colors.orange,
                onTap: () => context.go('/requests'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// BUNDLE STRIP SECTION  ── NEW ──
// ============================================================
class BundleStripSection extends ConsumerWidget {
  final String studentId;
  const BundleStripSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(activeSubscriptionsProvider(studentId));

    return subsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (subs) {
        if (subs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            AppThemeConstants.primaryAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.collections_bookmark_rounded,
                        size: 16,
                        color: AppThemeConstants.primaryAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'باقاتك النشطة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Count chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.primaryAmber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${subs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/active-subscriptions'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppThemeConstants.primaryAmber,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('عرض الكل',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_back_ios_new_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Horizontal scroll list ──────────────────────────
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
                itemCount: subs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => BundleStripCard(sub: subs[i]),
              ),
            ),
            Spacing.vLg,
          ],
        );
      },
    );
  }
}

// ── Individual bundle card ─────────────────────────────────────
class BundleStripCard extends StatelessWidget {
  final SubscriptionModel sub;
  const BundleStripCard({super.key, required this.sub});

  Color get _progressColor {
    final p = sub.progressPercentage;
    if (p >= 0.5) return AppThemeConstants.accentGreen;
    if (p >= 0.2) return const Color(0xFFFFA000);
    return AppThemeConstants.error;
  }

  bool get _isUrgent => sub.remainingSessions <= 2;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/active-subscriptions'),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeConstants.surfaceWhite,
          borderRadius: AppThemeConstants.borderRadiusLg,
          border: Border.all(
            color: _isUrgent
                ? AppThemeConstants.error.withValues(alpha: 0.5)
                : _progressColor.withValues(alpha: 0.25),
            width: _isUrgent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _progressColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppThemeConstants.primaryAmber.withValues(alpha: 0.15),
                  child: Text(
                    sub.mohaffezName.isNotEmpty ? sub.mohaffezName[0] : '؟',
                    style: const TextStyle(
                      color: AppThemeConstants.primaryAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.mohaffezName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                ),
                if (_isUrgent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚠️',
                      style: TextStyle(
                          fontSize: 10, color: AppThemeConstants.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Plan title
            Text(
              sub.planTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const Spacer(),
            // ── Progress bar ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: sub.progressPercentage,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            // ── Sessions counter ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${sub.remainingSessions}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _progressColor,
                        ),
                      ),
                      TextSpan(
                        text: '/${sub.totalSessions} جلسة',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick "book now" button
                if (sub.canBookSession)
                  GestureDetector(
                    onTap: () =>
                        context.push('/mohaffez/${sub.mohaffezId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.primaryAmber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'احجز',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// QUICK ACTIONS SECTION
// ============================================================
class QuickActionsSection extends StatelessWidget {
  final String studentId;
  const QuickActionsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الإجراءات السريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.textPrimary,
          ),
        ),
        Spacing.vMd,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            ActionCard(
              icon: Icons.search_rounded,
              title: 'ابحث عن محفظ',
              gradient: const LinearGradient(
                colors: [
                  AppThemeConstants.primaryAmber,
                  AppThemeConstants.primaryAmberLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.go('/nearby'),
            ),
            ActionCard(
              icon: Icons.event_available_rounded,
              title: 'جلساتي',
              gradient: const LinearGradient(
                colors: [
                  AppThemeConstants.accentGreen,
                  Color(0xFF66BB6A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.go('/my-sessions'),
            ),
            ActionCard(
              icon: Icons.assignment_rounded,
              title: 'واجباتي',
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.go('/assignments'),
            ),
            ActionCard(
              icon: Icons.calendar_month_rounded,
              title: 'الجدول الزمني',
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.go('/my-schedule'),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// RECENT ASSIGNMENTS SECTION
// ============================================================
class RecentAssignmentsSection extends ConsumerWidget {
  final String studentId;
  const RecentAssignmentsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync =
        ref.watch(studentSessionsFirstPageProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'آخر الواجبات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/assignments'),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: const Text('عرض الكل'),
              style: TextButton.styleFrom(
                foregroundColor: AppThemeConstants.primaryAmber,
              ),
            ),
          ],
        ),
        Spacing.vMd,
        sessionsAsync.when(
          data: (sessions) {
            final assignments = sessions
                .where((s) =>
                    ((s['hifzAssignment'] as String?) ?? '').isNotEmpty ||
                    ((s['murajaAssignment'] as String?) ?? '').isNotEmpty)
                .take(3)
                .toList();

            if (assignments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: AppThemeConstants.borderRadiusLg,
                  border: Border.all(
                    color: Colors.amber.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'لا توجد واجبات جديدة حالياً',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: assignments.map((session) {
                final mohaffezName =
                    (session['mohaffezName'] as String?) ?? 'محفظ';
                final hifz = (session['hifzAssignment'] as String?) ?? '';
                final muraja =
                    (session['murajaAssignment'] as String?) ?? '';
                final sessionDate = session['sessionDate'] as DateTime?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.surfaceWhite,
                    borderRadius: AppThemeConstants.borderRadiusLg,
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppThemeConstants.borderRadiusLg,
                    child: InkWell(
                      onTap: () => context.go('/assignments'),
                      borderRadius: AppThemeConstants.borderRadiusLg,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppThemeConstants.accentGreen
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        AppThemeConstants.borderRadiusSm,
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: AppThemeConstants.accentGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mohaffezName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeConstants.textPrimary,
                                    ),
                                  ),
                                ),
                                if (sessionDate != null)
                                  Text(
                                    '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              if (hifz.isNotEmpty)
                                AssignmentRow(
                                  label: 'حفظ',
                                  text: hifz,
                                  color: Colors.green.shade700,
                                ),
                              if (muraja.isNotEmpty)
                                AssignmentRow(
                                  label: 'مراجعة',
                                  text: muraja,
                                  color: Colors.blue.shade700,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: AppThemeConstants.borderRadiusLg,
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('حدث خطأ أثناء تحميل البيانات'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SHARED HELPER WIDGETS
// ============================================================
class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.surfaceWhite,
      borderRadius: AppThemeConstants.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppThemeConstants.borderRadiusLg,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: AppThemeConstants.borderRadiusLg,
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppThemeConstants.borderRadiusMd,
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              Spacing.vMd,
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: AppThemeConstants.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppThemeConstants.borderRadiusLg,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppThemeConstants.borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              Spacing.vSm,
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
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
              style: const TextStyle(fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
