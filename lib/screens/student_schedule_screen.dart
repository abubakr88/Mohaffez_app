// FILE: lib/screens/student_schedule_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';

/// Dedicated screen for calendar/timeline view of all sessions
class StudentScheduleScreen extends ConsumerStatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  ConsumerState<StudentScheduleScreen> createState() =>
      _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends ConsumerState<StudentScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String? _studentId;

  Future<void> _refreshSchedule() async {
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(user.uid));
    _studentId = user.uid;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: sessionsAsync.when(
          data: (sessions) {
            final acceptedSessions = sessions.where((s) {
              final status = (s['status'] as String?)?.toLowerCase();
              return status == 'accepted';
            }).toList();

            // Group sessions by date
            final sessionsByDate = <DateTime, List<Map<String, dynamic>>>{};
            for (final session in acceptedSessions) {
              final date = session['sessionDate'] as DateTime?;
              if (date != null) {
                final dateKey = DateTime(date.year, date.month, date.day);
                sessionsByDate.putIfAbsent(dateKey, () => []).add(session);
              }
            }

            return RefreshIndicator(
              onRefresh: _refreshSchedule,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  _buildAppBar(),

                  // Calendar
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        eventLoader: (day) {
                          final dateKey =
                              DateTime(day.year, day.month, day.day);
                          return sessionsByDate[dateKey] ?? [];
                        },
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color:
                                AppThemeConstants.primaryAmber.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: AppThemeConstants.accentGreen,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: AppThemeConstants.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: true,
                          titleCentered: true,
                          formatButtonShowsNext: false,
                        ),
                        locale: 'ar',
                      ),
                    ),
                  ),

                  // Sessions for selected day
                  _buildSessionsList(sessionsByDate),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('حدث خطأ: $e')),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => context.pop(),
              tooltip: 'رجوع',
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث',
          onPressed: _refreshSchedule,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple,
                Color(0xFFAB47BC),
              ],
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الجدول الزمني',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'عرض الجلسات في التقويم',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
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

  Widget _buildSessionsList(
      Map<DateTime, List<Map<String, dynamic>>> sessionsByDate) {
    if (_selectedDay == null) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.touch_app,
          title: 'اختر يوماً',
          message: 'اضغط على يوم في التقويم لعرض الجلسات',
          animated: true,
        ),
      );
    }

    final dateKey =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final sessions = sessionsByDate[dateKey] ?? [];

    if (sessions.isEmpty) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.event_busy,
          title: 'لا توجد جلسات',
          message: 'لا توجد جلسات في هذا اليوم',
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
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'الجلسات في ${DateFormat('EEEE، d MMMM yyyy', 'ar').format(_selectedDay!)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            final session = sessions[index - 1];
            return _SessionCard(session: session);
          },
          childCount: sessions.length + 1,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = (session['mohaffezName'] as String?) ?? 'محفظ';
    final sessionType = (session['sessionType'] as String?) ?? 'home';
    final timeSlot = (session['preferredTimeSlot'] as String?) ?? '';
    final location = (session['imamAddressText'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppThemeConstants.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.event,
            color: AppThemeConstants.accentGreen,
          ),
        ),
        title: Text(
          mohaffezName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_getSessionTypeLabel(sessionType)),
            if (timeSlot.isNotEmpty)
              Text('الوقت: $timeSlot', style: const TextStyle(fontSize: 12)),
            if (location.isNotEmpty)
              Text('الموقع: $location', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _getSessionTypeLabel(String type) {
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
