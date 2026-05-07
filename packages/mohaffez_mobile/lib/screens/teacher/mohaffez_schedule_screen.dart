// lib/screens/mohaffez_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/time_formatter.dart';

class MohaffezScheduleScreen extends ConsumerStatefulWidget {
  const MohaffezScheduleScreen({super.key});

  @override
  ConsumerState<MohaffezScheduleScreen> createState() =>
      _MohaffezScheduleScreenState();
}

class _MohaffezScheduleScreenState
    extends ConsumerState<MohaffezScheduleScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  CalendarFormat calendarFormat = CalendarFormat.month;
  String? mohaffezId;

  // ── FIX 1: catchError must return a List ──────────────────────────────────
  Future<void> _refreshSchedule() async {
    final id = mohaffezId;
    if (id == null) return;
    ref.invalidate(upcomingSessionsProvider(id));
    await ref
        .read(upcomingSessionsProvider(id).future)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    // ── FIX 2: currentUserProvider returns AsyncValue — use .value on the result
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    mohaffezId ??= user.uid;
    final sessionsAsync = ref.watch(upcomingSessionsProvider(user.uid));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: sessionsAsync.when(
          data: (sessions) {
            // Group sessions by date
            final Map<DateTime, List<Map<String, dynamic>>> sessionsByDate = {};
            for (final session in sessions) {
              final date = session['sessionDate'] as DateTime?;
              if (date == null) continue;
              final key = DateTime(date.year, date.month, date.day);
              sessionsByDate.putIfAbsent(key, () => []).add(session);
            }

            return RefreshIndicator(
              onRefresh: _refreshSchedule,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar<Map<String, dynamic>>(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: focusedDay,
                          calendarFormat: calendarFormat,
                          locale: 'ar',
                          selectedDayPredicate: (day) =>
                              isSameDay(selectedDay, day),
                          eventLoader: (day) {
                            final key =
                                DateTime(day.year, day.month, day.day);
                            return sessionsByDate[key] ?? const [];
                          },
                          onDaySelected: (selDay, focDay) {
                            setState(() {
                              selectedDay = selDay;
                              focusedDay = focDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() => calendarFormat = format);
                          },
                          onPageChanged: (focDay) {
                            setState(() => focusedDay = focDay);
                          },
                          calendarStyle: CalendarStyle(
                            isTodayHighlighted: true,
                            todayDecoration: BoxDecoration(
                              // ── FIX 3: withOpacity → withValues ─────────
                              color: AppThemeConstants.primary
                                  .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: AppThemeConstants.secondary,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: const BoxDecoration(
                              color: AppThemeConstants.secondary,
                              shape: BoxShape.circle,
                            ),
                            markersAlignment: Alignment.bottomCenter,
                            markersMaxCount: 3,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonShowsNext: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildSessionsList(sessionsByDate),
                ],
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(child: Text(e.toString())),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ──────────────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      floating: true,
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppThemeConstants.deepTeal,
      surfaceTintColor: AppThemeConstants.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppThemeConstants.tealGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // ── FIX 3: withOpacity → withValues ─────────────
                          color: AppThemeConstants.surface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_available,
                          size: 28,
                          color: AppThemeConstants.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'جدول مواعيد الطلاب',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'استعرض كل الجلسات حسب اليوم',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppThemeConstants.onPrimary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
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

  // ──────────────────────────────────────────────────────────────────────────
  // SESSIONS LIST
  // ── FIX 4: return type Widget (not SliverWidget — that class doesn't exist)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSessionsList(
    Map<DateTime, List<Map<String, dynamic>>> sessionsByDate,
  ) {
    if (selectedDay == null) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.touch_app,
          title: 'اختر يوماً من التقويم',
          message: 'اضغط على أي يوم في التقويم لرؤية مواعيد الجلسات.',
          animated: true,
        ),
      );
    }

    final key =
        DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day);
    final sessions = sessionsByDate[key] ?? const [];

    if (sessions.isEmpty) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.event_busy,
          title: 'لا توجد جلسات في هذا اليوم',
          message: 'اختر يوماً آخر من التقويم لرؤية الجلسات.',
          animated: true,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  DateFormat('EEEE d MMMM yyyy', 'ar').format(selectedDay!),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
            return _SessionCard(session: sessions[index - 1]);
          },
          childCount: sessions.length + 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final studentName = session['studentName'] as String? ?? '';
    final sessionType = session['sessionType'] as String? ?? '';
    final timeSlot = session['preferredTimeSlot'] as String? ??
        session['timeSlot'] as String? ??
        '';
    final location = session['imamAddressText'] as String? ?? '';
    final date = session['sessionDate'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // ── FIX 3: withOpacity → withValues ───────────────────────────
            color: AppThemeConstants.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.person,
            color: AppThemeConstants.secondary,
          ),
        ),
        title: Text(
          studentName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (sessionType.isNotEmpty)
              Text(
                _getSessionTypeLabel(sessionType),
                style: const TextStyle(fontSize: 13),
              ),
            if (timeSlot.isNotEmpty)
              Text(formatTimeToArabicAmPm(timeSlot), style: const TextStyle(fontSize: 12)),
            if (location.isNotEmpty)
              Text(location, style: const TextStyle(fontSize: 12)),
            if (date != null)
              Text(
                DateFormat('EEEE d MMMM yyyy', 'ar').format(date),
                style: const TextStyle(fontSize: 11, color: AppThemeConstants.grey600),
              ),
          ],
        ),
      ),
    );
  }

  String _getSessionTypeLabel(String type) {
    switch (type) {
      case 'home':    return 'منزل الطالب';
      case 'mosque':  return 'المسجد';
      case 'online':  return 'أونلاين';
      default:        return type;
    }
  }
}
