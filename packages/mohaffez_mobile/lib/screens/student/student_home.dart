import 'dart:async';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../providers/quiz_access_provider.dart';
import '../../services/app_version_service.dart';
import '../../shared/widgets/error_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS (consistent with mohaffez_home)
// ═══════════════════════════════════════════════════════════════════════════════
class _DS {
  static const teal800   = Color(0xFF095752);
  static const teal700   = Color(0xFF0C6F6A);
  static const teal600   = Color(0xFF0E8278);
  static const teal500   = Color(0xFF1A9E84);
  static const teal100   = Color(0xFFD4EDE7);
  static const teal50    = Color(0xFFEAF6F3);

  static const amber     = Color(0xFFE67E22);
  static const amberBg   = Color(0xFFFFF3E0);
  static const purple    = Color(0xFF7A5AF8);
  static const purpleBg  = Color(0xFFF0EEFF);
  static const green     = Color(0xFF2E8B57);
  static const greenBg   = Color(0xFFE8F5E9);
  static const gold      = Color(0xFFB7791F);
  static const goldBg    = Color(0xFFFFF8E1);
  static const darkTeal  = Color(0xFF0F766E);
  static const darkTealBg= Color(0xFFE0F2F1);

  static const bg      = Color(0xFFF4F7F6);
  static const text1   = Color(0xFF111827);
  static const text2   = Color(0xFF4B5563);
  static const text3   = Color(0xFF9CA3AF);
  static const border  = Color(0xFFE5EDE9);

  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0C6F6A).withValues(alpha: 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppThemeConstants.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: AppThemeConstants.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════════════════
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
          return const Scaffold(body: Center(child: Text('لم يتم تسجيل الدخول')));
        }
        return StudentHomeContent(studentId: user.uid);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(onRetry: () => ref.invalidate(currentUserProvider)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
class StudentHomeContent extends ConsumerWidget {
  final String studentId;
  const StudentHomeContent({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user              = ref.watch(currentUserProvider).value;
    final requestsAsync     = ref.watch(studentRequestsFirstPageProvider(studentId));
    final subscriptionsAsync = ref.watch(activeSubscriptionsProvider(studentId));
    final studentUpcomingAsync = ref.watch(studentUpcomingSessionsProvider(studentId));
    final now               = DateTime.now();

    final nextSessionDate = studentUpcomingAsync.when(
      data: (sessions) {
        debugPrint('👨‍🎓 Student upcoming sessions: ${sessions.length}');
        for (final s in sessions) {
          final d = s['sessionDate'] as DateTime?;
          debugPrint('📅 Student session: $d | isAfter(now): ${d?.isAfter(now)}');
        }
        final future = sessions.where((s) {
          final d = s['sessionDate'] as DateTime?;
          return d != null && d.isAfter(now);
        }).toList();
        debugPrint('⏰ Student future sessions: ${future.length}');
        if (future.isEmpty) return null;
        // Sort by actual datetime (sessionDate + slotStart) to get the earliest session
        future.sort((a, b) {
          final da = a['sessionDate'] as DateTime?;
          final db = b['sessionDate'] as DateTime?;
          if (da == null || db == null) return 0;
          final slotStartA = a['slotStart'] as DateTime?;
          final slotStartB = b['slotStart'] as DateTime?;
          if (slotStartA != null && slotStartB != null) {
            return slotStartA.compareTo(slotStartB);
          }
          return da.compareTo(db);
        });
        return future.first['sessionDate'] as DateTime?;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    final activeRequestsCount = requestsAsync.when(
      data: (requests) => requests.where((r) {
        final status = (r['status'] as String?)?.toLowerCase();
        return status == 'pending' || status == 'awaitingpayment';
      }).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final awaitingPaymentCount = requestsAsync.when(
      data: (requests) => requests.where((r) {
        final status = (r['status'] as String?)?.toLowerCase();
        return status == 'awaitingpayment';
      }).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final subscriptionsCount = subscriptionsAsync.when(
      data: (subs) => subs.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final upcomingSessionsCount = studentUpcomingAsync.when(
      data: (sessions) => sessions.where((s) {
        final d = s['sessionDate'] as DateTime?;
        return d != null && d.isAfter(now);
      }).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final requestsLoading     = requestsAsync is AsyncLoading;
    final subscriptionsLoading = subscriptionsAsync is AsyncLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _DS.bg,
          body: RefreshIndicator(
            color: _DS.teal500,
            backgroundColor: AppThemeConstants.white,
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
                // ─── Header ──────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 196,
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: _DS.teal700,
                  surfaceTintColor: AppThemeConstants.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _HomeHeader(
                      name:     user?.name ?? 'الطالب',
                      photoUrl: user?.photoUrl,
                      dateText: DateFormat('EEEE، d MMMM', 'ar').format(now),
                      greeting: _greeting(now, nextSessionDate),
                    ),
                  ),
                ),

                // ─── Stats row ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _StatsRow(
                    activeRequests:    activeRequestsCount,
                    subscriptionsCount: subscriptionsCount,
                    upcomingSessions:  upcomingSessionsCount,
                    requestsLoading:     requestsLoading,
                    subscriptionsLoading: subscriptionsLoading,
                  ),
                ),

                // ─── Body ────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (awaitingPaymentCount > 0) ...[
                        _PaymentAlertBanner(
                          count: awaitingPaymentCount,
                          onTap: () => context.go('/requests'),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _NextSessionCountdown(nextSessionDate: nextSessionDate),
                      if (nextSessionDate != null) const SizedBox(height: 20),
                      _ActionsSection(studentId: studentId),
                      const SizedBox(height: 20),
                      _QuizAccessCard(studentId: studentId),
                      const SizedBox(height: 28),
                      _AssignmentsSection(studentId: studentId),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _greeting(DateTime now, DateTime? nextSession) {
    if (nextSession != null) {
      final today = DateTime(now.year, now.month, now.day);
      final sessionDay = DateTime(nextSession.year, nextSession.month, nextSession.day);
      final diff = sessionDay.difference(today).inDays;
      if (diff == 0) {
        final timeStr = DateFormat('h:mm a', 'ar').format(nextSession);
        return 'جلستك اليوم الساعة $timeStr — استعد وراجع درسك';
      }
      if (diff == 1) return 'جلستك غداً — راجع سورة الأمس الآن';
      if (diff <= 3) return 'جلستك بعد $diff أيام — واصل المراجعة اليومية';
    }
    final h = now.hour;
    if (h < 4)  return 'ختم يومك بتلاوة قبل النوم';
    if (h < 7)  return 'وقت الفجر — ابدأ يومك بالحفظ';
    if (h < 12) return 'صباح الخير — جاهز لرحلة الحفظ اليوم؟';
    if (h < 14) return 'وقت الظهر — قليل من المراجعة يثبّت الحفظ';
    if (h < 17) return 'بعد الظهر وقت مثالي للمراجعة';
    if (h < 20) return 'بعد المغرب أفضل وقت لتثبيت الحفظ';
    return 'ختم يومك بتلاوة آيات قبل النوم';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String dateText;
  final String greeting;

  const _HomeHeader({
    required this.name,
    required this.photoUrl,
    required this.dateText,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_DS.teal800, _DS.teal600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeConstants.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20, right: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeConstants.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Avatar(name: name, photoUrl: photoUrl, size: 112),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: AppThemeConstants.white, letterSpacing: -0.3,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.white.withValues(alpha: 0.15),
                                borderRadius: _DS.r8,
                                border: Border.all(color: AppThemeConstants.white.withValues(alpha: 0.25)),
                              ),
                              child: const Text(
                                'طالب',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppThemeConstants.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 12,
                                    color: AppThemeConstants.white.withValues(alpha: 0.7)),
                                const SizedBox(width: 5),
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppThemeConstants.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Compact greeting chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.white.withValues(alpha: 0.13),
                      borderRadius: _DS.r12,
                      border: Border.all(color: AppThemeConstants.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppThemeConstants.white, size: 12),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            greeting,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppThemeConstants.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAYMENT ALERT BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _PaymentAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PaymentAlertBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: _DS.r16,
        child: Ink(
          decoration: BoxDecoration(
            color: _DS.amberBg,
            borderRadius: _DS.r16,
            border: Border.all(color: _DS.amber.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _DS.amber.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _DS.amber.withValues(alpha: 0.15),
                    borderRadius: _DS.r12,
                  ),
                  child: const Icon(Icons.payment_rounded, color: _DS.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لديك $count ${count == 1 ? "طلب بانتظار الدفع" : "طلبات بانتظار الدفع"}',
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _DS.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'اضغط لمراجعة الطلبات وإتمام الدفع',
                        style: TextStyle(fontSize: 12, color: _DS.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _DS.amber),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS ROW
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final int activeRequests;
  final int subscriptionsCount;
  final int upcomingSessions;
  final bool requestsLoading;
  final bool subscriptionsLoading;

  const _StatsRow({
    required this.activeRequests,
    required this.subscriptionsCount,
    required this.upcomingSessions,
    required this.requestsLoading,
    required this.subscriptionsLoading,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        icon: Icons.event_note_rounded,
        label: 'القادمة',
        value: subscriptionsLoading ? '…' : '$upcomingSessions',
        color: _DS.teal500,
        bg: _DS.teal50,
        onTap: () => context.push('/my-sessions'),
      ),
      _StatData(
        icon: Icons.workspace_premium_rounded,
        label: 'الباقات',
        value: subscriptionsLoading ? '…' : '$subscriptionsCount',
        color: _DS.green,
        bg: _DS.greenBg,
        onTap: () => context.push('/active-subscriptions'),
      ),
      _StatData(
        icon: Icons.hourglass_top_rounded,
        label: 'الطلبات',
        value: requestsLoading ? '…' : '$activeRequests',
        color: _DS.amber,
        bg: _DS.amberBg,
        isAlert: activeRequests > 0,
        onTap: () => context.go('/requests'),
      ),
    ];

    return Container(
      color: _DS.bg,
      child: Container(
        decoration: const BoxDecoration(
          color: _DS.teal700,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Row(
          children: List.generate(stats.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i < stats.length - 1 ? 8 : 0),
                child: _StatCard(data: stats[i]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool isAlert;
  final VoidCallback onTap;

  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.isAlert = false,
    required this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _DS.r16,
        boxShadow: _DS.cardShadow,
      ),
      child: Material(
        color: AppThemeConstants.white,
        borderRadius: _DS.r16,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            data.onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: data.isAlert ? data.color.withValues(alpha: 0.45) : _DS.border,
                width: data.isAlert ? 1.5 : 1,
              ),
              borderRadius: _DS.r16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored top stripe
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: data.isAlert ? 1.0 : 0.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: data.bg, borderRadius: _DS.r8),
                        child: Icon(data.icon, color: data.color, size: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: data.color,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data.label,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _DS.text2,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIONS SECTION
// ═══════════════════════════════════════════════════════════════════════════════
class _ActionsSection extends StatelessWidget {
  final String studentId;
  const _ActionsSection({required this.studentId});

  @override
  Widget build(BuildContext context) {
    final actions = [
      // ── Row 1: Daily actions ──
      _ActionData(icon: Icons.calendar_month_rounded, label: 'احجز جلسة',
          color: _DS.teal500, bg: _DS.teal50,
          onTap: () => context.go('/nearby')),
      _ActionData(icon: Icons.local_library_rounded, label: 'جلساتي',
          color: _DS.green, bg: _DS.greenBg,
          onTap: () => context.go('/my-sessions')),
      _ActionData(icon: Icons.task_alt_rounded, label: 'واجباتي',
          color: _DS.amber, bg: _DS.amberBg,
          onTap: () => context.go('/assignments')),
      // ── Row 2: Occasional ──
      _ActionData(icon: Icons.event_note_rounded, label: 'جدولي',
          color: _DS.darkTeal, bg: _DS.darkTealBg,
          onTap: () => context.go('/my-schedule')),
      _ActionData(icon: Icons.hourglass_top_rounded, label: 'طلباتي',
          color: _DS.purple, bg: _DS.purpleBg,
          onTap: () => context.go('/requests')),
      _ActionData(icon: Icons.wallet_rounded, label: 'اشتراكاتي',
          color: _DS.gold, bg: _DS.goldBg,
          onTap: () => context.push('/active-subscriptions')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'الإجراءات الرئيسية',
          subtitle: 'كل ما تحتاجه في مكان واحد',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 600
                ? 6
                : constraints.maxWidth > 380
                    ? 4
                    : 3;
            return GridView.builder(
              itemCount: actions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (_, i) => _ActionCard(data: actions[i]),
            );
          },
        ),
      ],
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionData({
    required this.icon, required this.label, required this.color,
    required this.bg, required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionData data;
  const _ActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          data.onTap();
        },
        borderRadius: _DS.r16,
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeConstants.white,
            borderRadius: _DS.r16,
            border: Border.all(color: _DS.border),
            boxShadow: _DS.subtleShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: data.bg, borderRadius: _DS.r12),
                  child: Icon(data.icon, color: data.color, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _DS.text1, height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUIZ ACCESS CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _QuizAccessCard extends ConsumerWidget {
  final String studentId;
  const _QuizAccessCard({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(quizUnlockedSessionProvider(studentId));

    final unlockInfo = quizAsync.valueOrNull;
    final isUnlocked = unlockInfo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'تحديات الجلسة',
          subtitle: 'يفتحها محفظك أثناء الجلسة',
        ),
        const SizedBox(height: 14),
        Material(
          color: AppThemeConstants.transparent,
          child: InkWell(
            onTap: isUnlocked
                ? () {
                    HapticFeedback.lightImpact();
                    context.push(
                      '/session-quiz'
                      '?mohaffezId=${unlockInfo.mohaffezId}'
                      '&studentId=$studentId'
                      '&sessionId=${unlockInfo.sessionId}',
                    );
                  }
                : () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'يفتح المحفظ التحديات أثناء الجلسة',
                          textDirection: TextDirection.rtl,
                        ),
                        backgroundColor: AppThemeConstants.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            borderRadius: _DS.r16,
            child: Ink(
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xFF0E8278) : AppThemeConstants.white,
                borderRadius: _DS.r16,
                border: Border.all(
                  color: isUnlocked
                      ? const Color(0xFF0E8278)
                      : _DS.border,
                  width: isUnlocked ? 0 : 1,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0E8278).withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : _DS.subtleShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? AppThemeConstants.white.withValues(alpha: 0.2)
                            : _DS.teal50,
                        borderRadius: _DS.r12,
                      ),
                      child: Icon(
                        isUnlocked
                            ? Icons.extension_rounded
                            : Icons.lock_rounded,
                        color: isUnlocked ? AppThemeConstants.white : _DS.text3,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUnlocked ? 'تحديات الجلسة — مفعّلة!' : 'تحديات الجلسة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isUnlocked ? AppThemeConstants.white : _DS.text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isUnlocked
                                ? 'اضغط لبدء تحديات الحفظ والتجويد'
                                : 'في انتظار المحفظ ليفتح التحديات',
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnlocked
                                  ? AppThemeConstants.white.withValues(alpha: 0.8)
                                  : _DS.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isUnlocked
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.lock_outline_rounded,
                      size: 16,
                      color: isUnlocked
                          ? AppThemeConstants.white.withValues(alpha: 0.8)
                          : _DS.text3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGNMENTS SECTION
// ═══════════════════════════════════════════════════════════════════════════════
class _AssignmentsSection extends ConsumerWidget {
  final String studentId;
  const _AssignmentsSection({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));

    final subtitle = sessionsAsync.when(
      data: (sessions) {
        final count = sessions
            .where((s) =>
                ((s['hifzAssignment'] as String?) ?? '').isNotEmpty ||
                ((s['murajaAssignment'] as String?) ?? '').isNotEmpty)
            .take(3)
            .length;
        if (count == 0) return 'لا توجد واجبات حالياً';
        return 'أحدث $count ${count == 1 ? "واجب من" : "واجبات من"} محفظك';
      },
      loading: () => 'جارٍ التحميل…',
      error: (_, __) => 'تعذر التحميل',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: 'آخر الواجبات',
          subtitle: subtitle,
          trailing: TextButton.icon(
            onPressed: () => context.go('/assignments'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 11),
            label: const Text('عرض الكل'),
            style: TextButton.styleFrom(
              foregroundColor: _DS.teal500,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        sessionsAsync.when(
          data: (sessions) {
            final assignments = sessions
                .where((s) =>
                    ((s['hifzAssignment'] as String?) ?? '').isNotEmpty ||
                    ((s['murajaAssignment'] as String?) ?? '').isNotEmpty)
                .take(3)
                .toList();

            if (assignments.isEmpty) {
              return const _EmptyCard(
                icon: Icons.assignment_late_outlined,
                title: 'لا توجد واجبات جديدة حالياً',
                subtitle: 'عند إضافة تكليف جديد سيظهر هنا مباشرة.',
              );
            }

            return Column(
              children: List.generate(assignments.length, (i) {
                final s = assignments[i];
                final mohaffezName = (s['mohaffezName'] as String?) ?? 'محفظ';
                final hifz = (s['hifzAssignment'] as String?) ?? '';
                final muraja = (s['murajaAssignment'] as String?) ?? '';
                final sessionDateRaw = s['sessionDate'];
                final sessionDate = sessionDateRaw is Timestamp
                    ? sessionDateRaw.toDate()
                    : sessionDateRaw as DateTime?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AssignmentCard(
                    mohaffezName: mohaffezName,
                    hifz: hifz,
                    muraja: muraja,
                    sessionDate: sessionDate,
                    colorIndex: i,
                    onTap: () => context.go('/assignments'),
                  ),
                );
              }),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const _EmptyCard(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل الواجبات',
            subtitle: 'اسحب للأسفل للمحاولة مرة أخرى.',
            isError: true,
          ),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String mohaffezName;
  final String hifz;
  final String muraja;
  final DateTime? sessionDate;
  final int colorIndex;
  final VoidCallback onTap;

  const _AssignmentCard({
    required this.mohaffezName,
    required this.hifz,
    required this.muraja,
    required this.sessionDate,
    required this.colorIndex,
    required this.onTap,
  });

  static String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff == 2) return 'قبل يومين';
    if (diff >= 3 && diff <= 10) return 'قبل $diff أيام';
    if (diff > 10) return 'قبل $diff يوم';
    return DateFormat('dd/MM', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    const colors = [_DS.teal500, _DS.green, _DS.purple];
    const bgs    = [_DS.teal50,  _DS.greenBg, _DS.purpleBg];
    final color  = colors[colorIndex % colors.length];
    final bg     = bgs[colorIndex % bgs.length];

    final relDate = _relativeDate(sessionDate);

    return Material(
      color: AppThemeConstants.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: _DS.r16,
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeConstants.white,
            borderRadius: _DS.r16,
            border: Border.all(color: _DS.border),
            boxShadow: _DS.subtleShadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: mohaffez name + relative date
                        Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: bg, borderRadius: _DS.r12),
                              child: Icon(Icons.person_rounded, color: color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                mohaffezName,
                                style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: _DS.text1,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (relDate.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _DS.teal50,
                                  borderRadius: _DS.r8,
                                  border: Border.all(color: _DS.teal100),
                                ),
                                child: Text(
                                  relDate,
                                  style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: _DS.teal600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Assignment rows
                        if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          if (hifz.isNotEmpty)
                            _AssignmentRow(label: 'حفظ', text: hifz, color: _DS.teal500),
                          if (muraja.isNotEmpty)
                            _AssignmentRow(label: 'مراجعة', text: muraja, color: _DS.green),
                        ],
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: _DS.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AssignmentRow({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: _DS.r8,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: _DS.text1, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEXT SESSION COUNTDOWN (IMPROVED)
// ═══════════════════════════════════════════════════════════════════════════════
class _NextSessionCountdown extends StatefulWidget {
  final DateTime? nextSessionDate;
  const _NextSessionCountdown({required this.nextSessionDate});

  @override
  State<_NextSessionCountdown> createState() => _NextSessionCountdownState();
}

class _NextSessionCountdownState extends State<_NextSessionCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recalculate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_recalculate);
    });
  }

  @override
  void didUpdateWidget(_NextSessionCountdown old) {
    super.didUpdateWidget(old);
    if (old.nextSessionDate != widget.nextSessionDate) _recalculate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _recalculate() {
    final d = widget.nextSessionDate;
    if (d == null) { _remaining = Duration.zero; return; }
    final diff = d.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  String _formatSessionDate(DateTime date) {
    final weekdays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final dayName = weekdays[date.weekday % 7];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'م' : 'ص';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$dayName $hour:$minute $period';
  }

  Widget _buildTimeUnit(String value, String label, bool isUrgent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isUrgent
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUrgent
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : _DS.gold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isUrgent ? const Color(0xFFDC2626) : _DS.gold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isUrgent ? const Color(0xFFDC2626) : _DS.text3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nextSessionDate == null) return const SizedBox.shrink();

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final isUrgent = _remaining.inHours < 1 && days == 0;
    final accentColor = isUrgent ? const Color(0xFFDC2626) : _DS.gold;
    final bgColor = isUrgent ? const Color(0xFFFEF2F2) : _DS.goldBg;
    final borderColor = isUrgent
        ? const Color(0xFFFCA5A5)
        : _DS.gold.withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: _DS.r16,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الجلسة القادمة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _DS.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSessionDate(widget.nextSessionDate!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _DS.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (days > 0) ...[
                _buildTimeUnit(days.toString().padLeft(2, '0'), 'يوم', isUrgent),
                _buildSeparator(isUrgent),
              ],
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'ساعة', isUrgent),
              _buildSeparator(isUrgent),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'دقيقة', isUrgent),
              if (days == 0) ...[
                _buildSeparator(isUrgent),
                _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'ثانية', isUrgent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(bool isUrgent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: isUrgent ? const Color(0xFFDC2626) : _DS.gold,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionLabel({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Decorative teal accent dot aligned to title
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 8),
                child: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: _DS.teal500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: _DS.text1, letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: _DS.text2, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isError;

  const _EmptyCard({
    required this.icon, required this.title, required this.subtitle, this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppThemeConstants.error : _DS.teal500;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: _DS.r16,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppThemeConstants.white, borderRadius: _DS.r16,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _DS.text1),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: _DS.text2, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const _Avatar({required this.name, required this.photoUrl, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? 'ط' : name.trim().substring(0, 1);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppThemeConstants.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: AppThemeConstants.white.withValues(alpha: 0.45), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.38, fontWeight: FontWeight.w800, color: AppThemeConstants.white,
                  ),
                ),
              ),
      ),
    );
  }
}
