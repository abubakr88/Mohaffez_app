// FILE: lib/screens/student_home.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/theme/app_theme_constants.dart';
import '../shared/theme/theme_extensions.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../services/app_version_service.dart';

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
            body: Center(child: Text('لم يتم العثور على بيانات المستخدم')),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.backgroundLight,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            ref.invalidate(studentSessionsFirstPageProvider(studentId));
            ref.invalidate(studentRequestsFirstPageProvider(studentId));
            await ref
                .read(studentSessionsFirstPageProvider(studentId).future)
                .catchError((_) => <Map<String, dynamic>>[]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Modern App Bar
              _buildAppBar(context, ref),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Welcome Message Card
                    _buildWelcomeCard(ref),
                    const SizedBox(height: 20),

                    // Quick Stats
                    QuickStatsSection(studentId: studentId),

                    Spacing.vLg,

                    // Quick Actions - UPDATED WITH CLEAR SEPARATION
                    QuickActionsSection(studentId: studentId),

                    Spacing.vLg,

                    // Recent Assignments Preview
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

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppThemeConstants.primaryAmber,
      flexibleSpace: FlexibleSpaceBar(
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
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
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
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                        child: const Icon(
                          Icons.waving_hand,
                          size: 28,
                          color: AppThemeConstants.surfaceWhite,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'مرحباً بك',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppThemeConstants.surfaceWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(currentUserProvider).value;
                      return Text(
                        user?.name ?? 'طالب',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.surfaceWhite,
                        ),
                      );
                    },
                  ),
                  Spacing.vSm,
                  Text(
                    DateFormat('EEEE، d MMMM yyyy', 'ar')
                        .format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              ),
            ),
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
                    'ابدأ يومك بحفظ القرآن الكريم',
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

// ========================================
// QUICK STATS SECTION
// ========================================
class QuickStatsSection extends ConsumerWidget {
  final String studentId;

  const QuickStatsSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync =
        ref.watch(studentSessionsFirstPageProvider(studentId));
    final requestsAsync =
        ref.watch(studentRequestsFirstPageProvider(studentId));

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
                title: 'جلساتي',
                value: sessionsAsync.when(
                  data: (sessions) => sessions
                      .where((s) => (s['status']) == 'accepted')
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: AppThemeConstants.accentGreen,
                onTap: () {
                  // Navigate to My Sessions screen (NEW)
                  context.go('/my-sessions');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.pending_actions,
                title: 'الطلبات المعلقة',
                value: requestsAsync.when(
                  data: (requests) => requests
                      .where((r) {
                        final status = (r['status'] as String?)?.toLowerCase();
                        return status == 'pending' ||
                            status == 'awaitingpayment';
                      })
                      .length
                      .toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: Colors.orange,
                onTap: () {
                  context.go('/requests');
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

  const StatCard({super.key, 
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
                    child: Icon(
                      icon,
                      size: 28,
                      color: color,
                    ),
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

// ========================================
// QUICK ACTIONS SECTION - UPDATED
// ========================================
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
            // SEARCH FOR NEARBY MOHAFFEZ
            ActionCard(
              icon: Icons.search,
              title: 'ابحث عن محفظ',
              gradient: const LinearGradient(
                colors: [
                  AppThemeConstants.primaryAmber,
                  AppThemeConstants.primaryAmberLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.go('/nearby');
              },
            ),

            // MY SESSIONS (NEW - Dedicated Screen)
            ActionCard(
              icon: Icons.event_available,
              title: 'جلساتي',
              gradient: const LinearGradient(
                colors: [
                  AppThemeConstants.accentGreen,
                  Color(0xFF66BB6A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                // Navigate to dedicated My Sessions screen
                context.go('/my-sessions');
              },
            ),

            // MY ASSIGNMENTS (Existing - But clearer purpose)
            ActionCard(
              icon: Icons.assignment,
              title: 'واجباتي',
              gradient: LinearGradient(
                colors: [
                  Colors.blue,
                  Colors.blue.shade300,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                context.go('/assignments');
              },
            ),

            // MY SCHEDULE (NEW - Calendar View)
            ActionCard(
              icon: Icons.calendar_today,
              title: 'الجدول الزمني',
              gradient: LinearGradient(
                colors: [
                  Colors.purple,
                  Colors.purple.shade300,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                // Navigate to dedicated Schedule screen
                context.go('/my-schedule');
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

  const ActionCard({super.key, 
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
              Icon(
                icon,
                size: 40,
                color: AppThemeConstants.surfaceWhite,
              ),
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

// ========================================
// RECENT ASSIGNMENTS SECTION
// ========================================
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                context.go('/assignments');
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('عرض الكل'),
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
              return Card(
                elevation: 0,
                color: Colors.amber.shade50,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppThemeConstants.borderRadiusLg,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'لا توجد واجبات جديدة حالياً',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: assignments.map((session) {
                final mohaffezName =
                    (session['mohaffezName'] as String?) ?? 'محفظ';
                final hifz = (session['hifzAssignment'] as String?) ?? '';
                final muraja = (session['murajaAssignment'] as String?) ?? '';
                final sessionDate = session['sessionDate'] as DateTime?;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.accentGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: AppThemeConstants.borderRadiusSm,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 18,
                                color: AppThemeConstants.accentGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                mohaffezName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (sessionDate != null)
                              Flexible(
                                child: Text(
                                  '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
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
                              color: Colors.green,
                            ),
                          if (muraja.isNotEmpty)
                            AssignmentRow(
                              label: 'مراجعة',
                              text: muraja,
                              color: Colors.blue,
                            ),
                        ],
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
                  const Expanded(
                    child: Text('حدث خطأ أثناء تحميل البيانات'),
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

class AssignmentRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const AssignmentRow({super.key, 
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
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
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
