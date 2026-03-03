// lib/screens/mohaffez_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/theme/app_theme_constants.dart';
import '../shared/theme/theme_extensions.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../models/request_status.dart';
import '../utils/arabic_labels.dart';
import '../services/app_version_service.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
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
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 100,
                floating: false,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                    onPressed: () {
                      ref.invalidate(currentUserProvider);
                      ref.invalidate(
                          pendingRequestsFirstPageProvider(mohaffezId));
                      ref.invalidate(upcomingSessionsProvider(mohaffezId));
                      ref.invalidate(acceptedSessionsCountProvider(mohaffezId));
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppThemeConstants.primaryAmber,
                          AppThemeConstants.primaryAmberLight
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppThemeConstants.surfaceWhite
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        AppThemeConstants.borderRadiusMd,
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    size: 32,
                                    color: AppThemeConstants.surfaceWhite,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final user =
                                          ref.watch(currentUserProvider).value;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'أهلاً بك',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: AppThemeConstants
                                                  .surfaceWhite
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          Text(
                                            user?.name ?? 'محفّظ',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: AppThemeConstants
                                                  .surfaceWhite,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Welcome Card
                    _buildWelcomeCard(ref),
                    const SizedBox(height: 20),

                    // Quick Stats
                    QuickStatsSection(mohaffezId: mohaffezId),
                    Spacing.vLg,

                    // Quick Actions
                    QuickActionsSection(mohaffezId: mohaffezId),
                    Spacing.vLg,

                    // Upcoming Sessions
                    UpcomingSessionsSection(mohaffezId: mohaffezId),
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

  Widget _buildWelcomeCard(WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'صباح الخير';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'مساء الخير';
      greetingIcon = Icons.wb_cloudy;
    } else {
      greeting = 'مساء الخير';
      greetingIcon = Icons.nights_stay;
    }

    return Card(
      elevation: 0,
      color: AppThemeConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.accentGreen.withValues(alpha: 0.1),
                borderRadius: AppThemeConstants.borderRadiusMd,
              ),
              child: Icon(
                greetingIcon,
                size: 28,
                color: AppThemeConstants.accentGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE، d MMMM yyyy', 'ar').format(now),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK STATS SECTION
// ============================================================================

class QuickStatsSection extends ConsumerWidget {
  final String mohaffezId;

  const QuickStatsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(RequestStatus.teacherInbox.isNotEmpty);
    final upcomingSessions = ref.watch(upcomingSessionsProvider(mohaffezId));
    final pendingRequestsCount =
        ref.watch(pendingRequestsCountProvider(mohaffezId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائياتك',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.textPrimary,
          ),
        ),
        Spacing.vMd,
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.event_available,
                title: ArabicLabels.upcomingSessions,
                value: upcomingSessions.when(
                  data: (sessions) => sessions.length.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: AppThemeConstants.accentGreen,
                onTap: () {
                  ref.read(upcomingSessionsFilterProvider.notifier).state =
                      UpcomingFilter.all;
                  context.push('/upcoming-sessions?mohaffezId=$mohaffezId');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.pending_actions,
                title: ArabicLabels.pendingRequests,
                value: pendingRequestsCount.toString(),
                color: Colors.orange,
                onTap: () {
                  context.push('/pending-requests?mohaffezId=$mohaffezId');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
    return Card(
      elevation: 0,
      color: AppThemeConstants.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
        side: BorderSide(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppThemeConstants.borderRadiusLg,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: AppThemeConstants.borderRadiusMd,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              Spacing.vMd,
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
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

// ============================================================================
// QUICK ACTIONS SECTION
// ============================================================================

class QuickActionsSection extends StatelessWidget {
  final String mohaffezId;

  const QuickActionsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 22,
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
            // Pending Requests
            ActionCard(
              icon: Icons.pending_actions,
              title: ArabicLabels.pendingRequests,
              gradient: const LinearGradient(
                colors: [Colors.orange, Color(0xFFFFB74D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/pending-requests?mohaffezId=$mohaffezId');
              },
            ),

            // Upcoming Sessions
            ActionCard(
              icon: Icons.event_available,
              title: ArabicLabels.upcomingSessions,
              gradient: const LinearGradient(
                colors: [AppThemeConstants.accentGreen, Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/upcoming-sessions?mohaffezId=$mohaffezId');
              },
            ),

            // ✅ NEW: Pricing Management
            ActionCard(
              icon: Icons.payments,
              title: 'إدارة الأسعار',
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/pricing-management');
              },
            ),

            // Platform Dues (Commissions)
            ActionCard(
              icon: Icons.account_balance_wallet,
              title: 'مستحقات المنصة',
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/mohaffez-commissions');
              },
            ),

            // My Students
            ActionCard(
              icon: Icons.groups,
              title: 'طلابي',
              gradient: const LinearGradient(
                colors: [Colors.purple, Color(0xFFAB47BC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.go('/my-students'),
            ),

            // Credentials
            ActionCard(
              icon: Icons.verified_user,
              title: 'الشهادات',
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Color(0xFF7E57C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/credentials');
              },
            ),

            // Availability
            ActionCard(
              icon: Icons.calendar_today,
              title: 'الأوقات المتاحة',
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.push('/availability');
              },
            ),
          ],
        ),
      ],
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
    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppThemeConstants.borderRadiusLg,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppThemeConstants.borderRadiusLg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppThemeConstants.surfaceWhite),
              Spacing.vSm,
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.surfaceWhite,
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

// ============================================================================
// UPCOMING SESSIONS SECTION
// ============================================================================

class UpcomingSessionsSection extends ConsumerWidget {
  final String mohaffezId;

  const UpcomingSessionsSection({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          ArabicLabels.upcomingSessions,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return Card(
                elevation: 0,
                color: AppThemeConstants.surfaceWhite,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppThemeConstants.borderRadiusLg,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Spacing.vMd,
                        Text(
                          'لا توجد جلسات قادمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: sessions.take(3).map((session) {
                final studentName = session['studentName'] as String? ??
                    ArabicLabels.notSpecified;
                final sessionDate = session['sessionDate'] as DateTime?;
                final timeSlot =
                    session['preferredTimeSlot'] as String? ?? '08:00';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: AppThemeConstants.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppThemeConstants.borderRadiusLg,
                    side: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppThemeConstants.accentGreen
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: AppThemeConstants.accentGreen,
                            size: 22,
                          ),
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
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sessionDate != null
                                        ? DateFormat('dd/MM/yyyy', 'ar')
                                            .format(sessionDate)
                                        : ArabicLabels.notSpecified,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeSlot,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
          error: (e, _) => Card(
            elevation: 0,
            color: Colors.red.shade50,
            shape: const RoundedRectangleBorder(
              borderRadius: AppThemeConstants.borderRadiusLg,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'خطأ في تحميل الجلسات',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
