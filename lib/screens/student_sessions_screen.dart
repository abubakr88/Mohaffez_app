// FILE: lib/screens/student_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';

class StudentSessionsScreen extends ConsumerStatefulWidget {
  const StudentSessionsScreen({super.key});

  @override
  ConsumerState<StudentSessionsScreen> createState() =>
      _StudentSessionsScreenState();
}

class _StudentSessionsScreenState
    extends ConsumerState<StudentSessionsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all';
  String? _studentId;
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppThemeConstants.durationNormal,
    )..forward();
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _refreshSessions() async {
    final studentId = _studentId;
    if (studentId == null) return;
    ref.invalidate(studentSessionsFirstPageProvider(studentId));
    await ref
        .read(studentSessionsFirstPageProvider(studentId).future)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _studentId = user.uid;
    final sessionsAsync =
        ref.watch(studentSessionsFirstPageProvider(user.uid));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.backgroundLight,
        body: RefreshIndicator(
          onRefresh: _refreshSessions,
          color: AppThemeConstants.accentGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(sessionsAsync),
              SliverToBoxAdapter(
                child: sessionsAsync.maybeWhen(
                  data: (s) => _buildStatsStrip(s),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              SliverToBoxAdapter(child: _buildFilterChips(sessionsAsync)),
              sessionsAsync.when(
                data: (s) => _buildSessionList(s),
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppThemeConstants.accentGreen),
                  ),
                ),
                error: (_, __) =>
                    SliverFillRemaining(child: _buildErrorState()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────

  Widget _buildAppBar(AsyncValue<List<Map<String, dynamic>>> sessionsAsync) {
    final totalCount = sessionsAsync.maybeWhen(
      data: (s) => s.where((x) {
        final st = (x['status'] as String?)?.toLowerCase();
        return st == 'accepted' || st == 'completed';
      }).length,
      orElse: () => null,
    );

    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppThemeConstants.accentGreenDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppThemeConstants.accentGreenDark,
                AppThemeConstants.accentGreen,
                AppThemeConstants.accentGreenLight,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                        child: const Icon(Icons.event_available_rounded,
                            size: 26, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جلساتي',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'إدارة جلساتك المؤكدة',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      if (totalCount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: AppThemeConstants.borderRadiusXl,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '$totalCount جلسة',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
    );
  }

  // ─────────────────────────────────────────────────
  // STATS STRIP
  // ─────────────────────────────────────────────────

  Widget _buildStatsStrip(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final all = sessions.where((s) {
      final st = (s['status'] as String?)?.toLowerCase();
      return st == 'accepted' || st == 'completed';
    }).toList();

    final upcoming = all.where((s) {
      final d = s['sessionDate'] as DateTime?;
      return d != null && !d.isBefore(todayStart);
    }).length;

    final completed = all.where((s) {
      final d = s['sessionDate'] as DateTime?;
      return d != null && d.isBefore(todayStart);
    }).length;

    final withAssignments = all.where((s) =>
        ((s['hifzAssignment'] as String?) ?? '').isNotEmpty ||
        ((s['murajaAssignment'] as String?) ?? '').isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppThemeConstants.surfaceWhite,
        borderRadius: AppThemeConstants.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(count: all.length, label: 'المجموع',
              color: AppThemeConstants.accentGreen,
              icon: Icons.grid_view_rounded),
          _StatDivider(),
          _StatItem(count: upcoming, label: 'القادمة',
              color: AppThemeConstants.info,
              icon: Icons.upcoming_rounded),
          _StatDivider(),
          _StatItem(count: completed, label: 'المنتهية',
              color: AppThemeConstants.textSecondary,
              icon: Icons.history_rounded),
          _StatDivider(),
          _StatItem(count: withAssignments, label: 'بواجبات',
              color: AppThemeConstants.primaryAmber,
              icon: Icons.assignment_rounded),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // FILTER CHIPS
  // ─────────────────────────────────────────────────

  Widget _buildFilterChips(
      AsyncValue<List<Map<String, dynamic>>> sessionsAsync) {
    final sessions = sessionsAsync.valueOrNull ?? [];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final all = sessions.where((s) {
      final st = (s['status'] as String?)?.toLowerCase();
      return st == 'accepted' || st == 'completed';
    }).toList();

    int countFor(String f) {
      if (f == 'all') return all.length;
      if (f == 'upcoming') {
        return all.where((s) {
          final d = s['sessionDate'] as DateTime?;
          return d != null && !d.isBefore(todayStart);
        }).length;
      }
      return all.where((s) {
        final d = s['sessionDate'] as DateTime?;
        return d != null && d.isBefore(todayStart);
      }).length;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildChip('all', 'الكل', Icons.grid_view_rounded, countFor('all')),
          const SizedBox(width: 8),
          _buildChip('upcoming', 'القادمة', Icons.upcoming_rounded,
              countFor('upcoming')),
          const SizedBox(width: 8),
          _buildChip('completed', 'المنتهية', Icons.history_rounded,
              countFor('completed')),
        ],
      ),
    );
  }

  Widget _buildChip(String value, String label, IconData icon, int count) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = value),
        child: AnimatedContainer(
          duration: AppThemeConstants.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppThemeConstants.accentGreen
                : AppThemeConstants.surfaceWhite,
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(
              color: isSelected
                  ? AppThemeConstants.accentGreen
                  : AppThemeConstants.divider,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppThemeConstants.accentGreen
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : AppThemeConstants.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : AppThemeConstants.textSecondary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppThemeConstants.accentGreen
                            .withValues(alpha: 0.15),
                    borderRadius: AppThemeConstants.borderRadiusRound,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppThemeConstants.accentGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // SESSION LIST
  // ─────────────────────────────────────────────────

  Widget _buildSessionList(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    var filtered = sessions.where((s) {
      final st = (s['status'] as String?)?.toLowerCase();
      return st == 'accepted' || st == 'completed';
    }).toList();

    if (_selectedFilter == 'upcoming') {
      filtered = filtered
          .where((s) {
            final d = s['sessionDate'] as DateTime?;
            return d != null && !d.isBefore(todayStart);
          })
          .toList()
        ..sort((a, b) {
          final da = a['sessionDate'] as DateTime?;
          final db = b['sessionDate'] as DateTime?;
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
    } else if (_selectedFilter == 'completed') {
      filtered = filtered
          .where((s) {
            final d = s['sessionDate'] as DateTime?;
            return d != null && d.isBefore(todayStart);
          })
          .toList()
        ..sort((a, b) {
          final da = a['sessionDate'] as DateTime?;
          final db = b['sessionDate'] as DateTime?;
          if (da == null || db == null) return 0;
          return db.compareTo(da);
        });
    } else {
      filtered.sort((a, b) {
        final da = a['sessionDate'] as DateTime?;
        final db = b['sessionDate'] as DateTime?;
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    }

    if (filtered.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ctrl = _animController;
            if (ctrl == null) return _SessionCard(session: filtered[index]);
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: ctrl,
                curve: Interval(
                  (index * 0.05).clamp(0.0, 0.8),
                  ((index * 0.05) + 0.4).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
              child: _SessionCard(session: filtered[index]),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final configs = {
      'upcoming': (
        'لا توجد جلسات قادمة',
        'لم يتم جدولة أي جلسات قادمة بعد',
        Icons.event_available_rounded
      ),
      'completed': (
        'لا توجد جلسات منتهية',
        'ستظهر جلساتك المنتهية هنا',
        Icons.history_rounded
      ),
    };
    final cfg = configs[_selectedFilter];
    return EmptyState(
      icon: cfg?.$3 ?? Icons.event_busy_rounded,
      title: cfg?.$1 ?? 'لا توجد جلسات',
      message:
          cfg?.$2 ?? 'ابدأ بحجز جلستك الأولى مع أحد المحفظين',
      animated: true,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 56,
              color: AppThemeConstants.error.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ أثناء التحميل',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.textPrimary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _refreshSessions,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(
                foregroundColor: AppThemeConstants.accentGreen),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _StatItem(
      {required this.count,
      required this.label,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppThemeConstants.borderRadiusSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppThemeConstants.textSecondary)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 48, color: AppThemeConstants.divider);
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = (session['mohaffezName'] as String?) ?? 'محفظ';
    final sessionType = (session['sessionType'] as String?) ?? 'home';
    final location = (session['imamAddressText'] as String?) ?? '';
    final timeSlot = (session['preferredTimeSlot'] as String?) ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;
    final hifz = (session['hifzAssignment'] as String?) ?? '';
    final muraja = (session['murajaAssignment'] as String?) ?? '';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isUpcoming =
        sessionDate != null && !sessionDate.isBefore(todayStart);
    final isToday = sessionDate != null &&
        sessionDate.year == now.year &&
        sessionDate.month == now.month &&
        sessionDate.day == now.day;

    final daysUntil = (isUpcoming && !isToday && sessionDate != null)
        ? sessionDate.difference(todayStart).inDays
        : null;

    final accentColor = isToday
        ? AppThemeConstants.warning
        : isUpcoming
            ? AppThemeConstants.accentGreen
            : AppThemeConstants.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppThemeConstants.surfaceWhite,
        borderRadius: AppThemeConstants.borderRadiusLg,
        border: Border.all(
          color: accentColor.withValues(alpha: isUpcoming ? 0.5 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppThemeConstants.borderRadiusLg,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 5, color: accentColor),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          _SessionTypeAvatar(
                              sessionType: sessionType,
                              isCompleted: !isUpcoming),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mohaffezName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppThemeConstants.textPrimary)),
                                const SizedBox(height: 2),
                                Text(_getSessionTypeLabel(sessionType),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppThemeConstants.textSecondary)),
                              ],
                            ),
                          ),
                          _StatusBadge(
                              isToday: isToday,
                              isUpcoming: isUpcoming,
                              daysUntil: daysUntil),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(
                          height: 1, color: AppThemeConstants.divider),
                      const SizedBox(height: 10),

                      // Info chips
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (sessionDate != null)
                            _InfoChip(
                              icon: Icons.calendar_today_rounded,
                              text: _smartDate(sessionDate, todayStart),
                              color: isUpcoming
                                  ? AppThemeConstants.accentGreen
                                  : AppThemeConstants.textSecondary,
                            ),
                          if (timeSlot.isNotEmpty)
                            _InfoChip(
                              icon: Icons.access_time_rounded,
                              text: timeSlot,
                              color: AppThemeConstants.info,
                            ),
                          if (location.isNotEmpty)
                            _InfoChip(
                              icon: Icons.location_on_rounded,
                              text: location,
                              color: AppThemeConstants.primaryAmber,
                              maxWidth: 150,
                            ),
                        ],
                      ),

                      // Assignments
                      if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(
                            height: 1, color: AppThemeConstants.divider),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.assignment_rounded,
                                size: 13,
                                color: AppThemeConstants.primaryAmber),
                            SizedBox(width: 5),
                            Text('الواجبات',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppThemeConstants.primaryAmber)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (hifz.isNotEmpty)
                          _AssignmentRow(
                              label: 'حفظ',
                              text: hifz,
                              color: AppThemeConstants.accentGreen),
                        if (muraja.isNotEmpty)
                          _AssignmentRow(
                              label: 'مراجعة',
                              text: muraja,
                              color: AppThemeConstants.info),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _smartDate(DateTime date, DateTime todayStart) {
    final diff = date.difference(todayStart).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غداً';
    if (diff == -1) return 'أمس';
    return DateFormat('d MMM', 'ar').format(date);
  }

  static String _getSessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'جلسة منزلية';
      case 'mosque':
        return 'جلسة في المسجد';
      case 'online':
        return 'جلسة أونلاين';
      default:
        return type;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTypeAvatar extends StatelessWidget {
  final String sessionType;
  final bool isCompleted;

  const _SessionTypeAvatar(
      {required this.sessionType, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (sessionType) {
      case 'mosque':
        icon = Icons.mosque_rounded;
        color = AppThemeConstants.primaryAmber;
        break;
      case 'online':
        icon = Icons.videocam_rounded;
        color = AppThemeConstants.info;
        break;
      default:
        icon = Icons.home_rounded;
        color = AppThemeConstants.accentGreen;
    }
    if (isCompleted) color = AppThemeConstants.textSecondary;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppThemeConstants.borderRadiusMd,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isToday;
  final bool isUpcoming;
  final int? daysUntil;

  const _StatusBadge(
      {required this.isToday,
      required this.isUpcoming,
      required this.daysUntil});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (isToday) {
      color = AppThemeConstants.warning;
      label = 'اليوم';
    } else if (daysUntil != null && daysUntil! <= 3) {
      color = AppThemeConstants.info;
      label = 'بعد $daysUntil أيام';
    } else if (isUpcoming) {
      color = AppThemeConstants.accentGreen;
      label = 'قادمة';
    } else {
      color = AppThemeConstants.textSecondary;
      label = 'منتهية';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppThemeConstants.borderRadiusRound,
        border:
            Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double? maxWidth;

  const _InfoChip(
      {required this.icon,
      required this.text,
      required this.color,
      this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 200),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                color: AppThemeConstants.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AssignmentRow(
      {required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppThemeConstants.borderRadiusXs,
              border:
                  Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeConstants.textPrimary,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
