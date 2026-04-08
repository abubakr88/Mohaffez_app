import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
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
  static const blue      = Color(0xFF2563EB);
  static const blueBg    = Color(0xFFE3F2FD);
  static const red       = Color(0xFFDC2626);
  static const redBg     = Color(0xFFFFEBEE);
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
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════════════════
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
        return MohaffezHomeContent(mohaffezId: user.uid);
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
class MohaffezHomeContent extends ConsumerWidget {
  final String mohaffezId;
  const MohaffezHomeContent({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(RequestStatus.teacherInbox.isNotEmpty);

    final user             = ref.watch(currentUserProvider).value;
    final upcomingSessions = ref.watch(upcomingSessionsProvider(mohaffezId));
    final pendingCount     = ref.watch(pendingRequestsCountProvider(mohaffezId));
    final now              = DateTime.now();

    final todayCount = upcomingSessions.when(
      data: (sessions) => sessions.where((s) {
        final d = s['sessionDate'] as DateTime?;
        return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
      }).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _DS.bg,
          body: RefreshIndicator(
            color: _DS.teal500,
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
              ref.invalidate(upcomingSessionsProvider(mohaffezId));
              await ref
                  .read(upcomingSessionsProvider(mohaffezId).future)
                  .catchError((_) => <Map<String, dynamic>>[]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ─── Header SliverAppBar ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 188,
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: _DS.teal700,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _HomeHeader(
                      name:         user?.name ?? 'المحفظ',
                      photoUrl:     user?.photoUrl,
                      dateText:     DateFormat('EEEE، d MMMM', 'ar').format(now),
                      greeting:     _greeting(now),
                      pendingCount: pendingCount,
                    ),
                  ),
                ),

                // ─── Stat cards pinned below header ───────────────────────
                SliverToBoxAdapter(
                  child: _StatsRow(
                    mohaffezId:       mohaffezId,
                    todayCount:       todayCount,
                    upcomingSessions: upcomingSessions,
                    pendingCount:     pendingCount,
                  ),
                ),

                // ─── Body ─────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (pendingCount > 0) ...[
                        _PendingAlertBanner(
                          count: pendingCount,
                          onTap: () => context.push('/pending-requests?mohaffezId=$mohaffezId'),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _ActionsSection(mohaffezId: mohaffezId),
                      const SizedBox(height: 28),
                      _UpcomingSection(mohaffezId: mohaffezId),
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

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'صباح الخير — ابدأ يومك بمراجعة الجلسات';
    if (h < 17) return 'مساء الخير — راجع جدول اليوم';
    return 'مساء النور — راجع مخرجات اليوم';
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
  final int pendingCount;

  const _HomeHeader({
    required this.name,
    required this.photoUrl,
    required this.dateText,
    required this.greeting,
    required this.pendingCount,
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
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20, right: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Avatar(name: name, photoUrl: photoUrl, size: 92),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: -0.3,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: _DS.r8,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const Text(
                                'معلم',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 11,
                                    color: Colors.white.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (pendingCount > 0) _PendingBadge(count: pendingCount),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Compact greeting chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: _DS.r12,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            greeting,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.95),
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

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: _DS.amber,
        borderRadius: _DS.r12,
        boxShadow: [
          BoxShadow(
            color: _DS.amber.withValues(alpha: 0.4),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            '$count ${count == 1 ? "طلب" : "طلبات"}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PENDING ALERT BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _PendingAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingAlertBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
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
                  child: const Icon(Icons.pending_actions_rounded, color: _DS.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لديك $count ${count == 1 ? "طلب معلق" : "طلبات معلقة"}',
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _DS.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'اضغط لمراجعة الطلبات والرد عليها',
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
// STATS ROW — sits in a teal container that rounds off the header bottom
// ═══════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final String mohaffezId;
  final int todayCount;
  final AsyncValue<List<Map<String, dynamic>>> upcomingSessions;
  final int pendingCount;

  const _StatsRow({
    required this.mohaffezId,
    required this.todayCount,
    required this.upcomingSessions,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        icon: Icons.pending_actions_rounded,
        label: 'معلقة',
        value: '$pendingCount',
        color: _DS.amber,
        bg: _DS.amberBg,
        isAlert: pendingCount > 0,
        onTap: () => context.push('/pending-requests?mohaffezId=$mohaffezId'),
      ),
      _StatData(
        icon: Icons.today_rounded,
        label: 'اليوم',
        value: '$todayCount',
        color: _DS.teal500,
        bg: _DS.teal50,
        onTap: () => context.go('/teacher-schedule'),
      ),
      _StatData(
        icon: Icons.event_available_rounded,
        label: 'القادمة',
        value: upcomingSessions.when(
          data: (s) => '${s.length}', loading: () => '…', error: (_, __) => '0',
        ),
        color: _DS.green,
        bg: _DS.greenBg,
        onTap: () => context.push('/upcoming-sessions?mohaffezId=$mohaffezId'),
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
        color: Colors.white,
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
  final String mohaffezId;
  const _ActionsSection({required this.mohaffezId});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(icon: Icons.pending_actions_rounded, label: 'الطلبات',
          color: _DS.amber, bg: _DS.amberBg,
          onTap: () => context.push('/pending-requests?mohaffezId=$mohaffezId')),
      _ActionData(icon: Icons.calendar_month_rounded, label: 'الجدول',
          color: _DS.teal500, bg: _DS.teal50,
          onTap: () => context.go('/teacher-schedule')),
      _ActionData(icon: Icons.event_note_rounded, label: 'القادمة',
          color: _DS.green, bg: _DS.greenBg,
          onTap: () => context.push('/upcoming-sessions?mohaffezId=$mohaffezId')),
      _ActionData(icon: Icons.sell_rounded, label: 'الأسعار',
          color: _DS.purple, bg: _DS.purpleBg,
          onTap: () => context.push('/pricing-management')),
      _ActionData(icon: Icons.receipt_long_rounded, label: 'المستحقات',
          color: _DS.gold, bg: _DS.goldBg,
          onTap: () => context.push('/mohaffez-commissions')),
      _ActionData(icon: Icons.groups_rounded, label: 'طلابي',
          color: _DS.darkTeal, bg: _DS.darkTealBg,
          onTap: () => context.go('/my-students')),
      _ActionData(icon: Icons.workspace_premium_rounded, label: 'الشهادات',
          color: _DS.blue, bg: _DS.blueBg,
          onTap: () => context.push('/credentials')),
      _ActionData(icon: Icons.calendar_view_week_rounded, label: 'التوفر',
          color: _DS.red, bg: _DS.redBg,
          onTap: () => context.push('/availability')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'الإجراءات الرئيسية',
          subtitle: 'اختصارات سريعة لإدارة يومك',
        ),
        const SizedBox(height: 14),
        GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (_, i) => _ActionCard(data: actions[i]),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          data.onTap();
        },
        borderRadius: _DS.r16,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
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
// UPCOMING SESSIONS
// ═══════════════════════════════════════════════════════════════════════════════
class _UpcomingSection extends ConsumerWidget {
  final String mohaffezId;
  const _UpcomingSection({required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId));

    final subtitle = sessionsAsync.when(
      data: (s) {
        if (s.isEmpty) return 'لا توجد جلسات قادمة حالياً';
        final count = s.length.clamp(1, 3);
        return 'أقرب $count ${count == 1 ? "جلسة تحتاج" : "جلسات تحتاج"} انتباهك';
      },
      loading: () => 'جارٍ التحميل…',
      error: (_, __) => 'تعذر التحميل',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: ArabicLabels.upcomingSessions,
          subtitle: subtitle,
          trailing: TextButton.icon(
            onPressed: () => context.push('/upcoming-sessions?mohaffezId=$mohaffezId'),
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
            if (sessions.isEmpty) {
              return const _EmptyCard(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد جلسات قادمة',
                subtitle: 'سيظهر جدولك هنا عند إضافة جلسات جديدة.',
              );
            }
            return Column(
              children: List.generate(sessions.take(3).length, (i) {
                final s = sessions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionCard(
                    studentName: s['studentName'] as String? ?? ArabicLabels.notSpecified,
                    sessionDate: s['sessionDate'] as DateTime?,
                    timeSlot: s['preferredTimeSlot'] as String? ?? '08:00',
                    colorIndex: i,
                    onTap: () => context.push('/upcoming-sessions?mohaffezId=$mohaffezId'),
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
            title: 'تعذر تحميل الجلسات',
            subtitle: 'اسحب للأسفل للمحاولة مرة أخرى.',
            isError: true,
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String studentName;
  final DateTime? sessionDate;
  final String timeSlot;
  final int colorIndex;
  final VoidCallback? onTap;

  const _SessionCard({
    required this.studentName,
    required this.sessionDate,
    required this.timeSlot,
    required this.colorIndex,
    this.onTap,
  });

  static String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غداً';
    if (diff > 1 && diff <= 6) return 'بعد $diff أيام';
    return DateFormat('dd/MM', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    const colors = [_DS.teal500, _DS.green, _DS.purple];
    const bgs    = [_DS.teal50,  _DS.greenBg, _DS.purpleBg];
    final color  = colors[colorIndex % colors.length];
    final bg     = bgs[colorIndex % bgs.length];

    final now = DateTime.now();
    final isToday = sessionDate != null &&
        sessionDate!.year == now.year &&
        sessionDate!.month == now.month &&
        sessionDate!.day == now.day;

    final relDate = _relativeDate(sessionDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: _DS.r16,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: _DS.r16,
            border: Border.all(color: isToday ? color.withValues(alpha: 0.3) : _DS.border),
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
                Container(
                  width: 44, height: 44,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: bg, borderRadius: _DS.r12),
                  child: Icon(Icons.person_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                studentName,
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
                                  color: isToday ? color.withValues(alpha: 0.1) : _DS.teal50,
                                  borderRadius: _DS.r8,
                                  border: Border.all(
                                    color: isToday ? color.withValues(alpha: 0.35) : _DS.teal100,
                                  ),
                                ),
                                child: Text(
                                  relDate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isToday ? color : _DS.teal600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          children: [
                            _InfoPill(
                              icon: Icons.calendar_today_rounded,
                              text: sessionDate == null
                                  ? ArabicLabels.notSpecified
                                  : DateFormat('dd/MM/yyyy', 'ar').format(sessionDate!),
                            ),
                            _InfoPill(icon: Icons.access_time_rounded, text: timeSlot),
                          ],
                        ),
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _DS.text3),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: _DS.text2, height: 1.4)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED
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
              color: Colors.white, borderRadius: _DS.r16,
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
    final initials = name.trim().isEmpty ? 'م' : name.trim().substring(0, 1);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(photoUrl!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.38, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}
