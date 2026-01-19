// screens/upcoming_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_completion_screen.dart'; // ✅ استيراد الشاشة الجديدة

class UpcomingSessionsScreen extends ConsumerWidget {
  final String mohaffezId;

  const UpcomingSessionsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId));
    final filter = ref.watch(upcomingSessionsFilterProvider);
    final filteredSessions =
        ref.watch(filteredUpcomingSessionsProvider(mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // App Bar with Filter
            SliverAppBar(
              expandedHeight: 130,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentGreen, Color(0xFF66BB6A)],
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
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event_available,
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
                                      'الجلسات القادمة',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'جلساتك المجدولة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Total Count Badge
                              sessionsAsync.when(
                                data: (sessions) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    sessions.length.toString(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
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

            // Filter Chips
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تصفية حسب:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('الكل'),
                          selected: filter == UpcomingFilter.all,
                          onSelected: (_) {
                            ref.read(upcomingSessionsFilterProvider.notifier).state =
                                UpcomingFilter.all;
                          },
                          selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.accentGreen,
                        ),
                        FilterChip(
                          label: const Text('اليوم'),
                          selected: filter == UpcomingFilter.today,
                          onSelected: (_) {
                            ref.read(upcomingSessionsFilterProvider.notifier).state =
                                UpcomingFilter.today;
                          },
                          selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.accentGreen,
                        ),
                        FilterChip(
                          label: const Text('هذا الأسبوع'),
                          selected: filter == UpcomingFilter.thisWeek,
                          onSelected: (_) {
                            ref.read(upcomingSessionsFilterProvider.notifier).state =
                                UpcomingFilter.thisWeek;
                          },
                          selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.accentGreen,
                        ),
                        FilterChip(
                          label: const Text('هذا الشهر'),
                          selected: filter == UpcomingFilter.thisMonth,
                          onSelected: (_) {
                            ref.read(upcomingSessionsFilterProvider.notifier).state =
                                UpcomingFilter.thisMonth;
                          },
                          selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.accentGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Filtered Count
                    Text(
                      'عدد الجلسات: ${filteredSessions.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sessions List
            sessionsAsync.when(
              data: (allSessions) {
                if (allSessions.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.event_busy,
                      title: 'لا توجد جلسات قادمة',
                      message: 'لم يتم جدولة أي جلسات بعد',
                      animated: true,
                    ),
                  );
                }

                if (filteredSessions.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.filter_list_off,
                      title: 'لا توجد نتائج',
                      message: 'لا توجد جلسات في الفترة المحددة',
                      animated: true,
                      action: TextButton.icon(
                        onPressed: () {
                          ref.read(upcomingSessionsFilterProvider.notifier).state =
                              UpcomingFilter.all;
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('مسح التصفية'),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = filteredSessions[index];
                        return SessionCard(
                          session: session,
                          mohaffezId: mohaffezId,
                        );
                      },
                      childCount: filteredSessions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: ErrorDisplay.dataLoad(
                  onRetry: () {
                    ref.invalidate(upcomingSessionsProvider(mohaffezId));
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ✅ SESSION CARD WIDGET - محدثة
class SessionCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final String mohaffezId;

  const SessionCard({
    super.key,
    required this.session,
    required this.mohaffezId,
  });

  // ✅ دالة للحصول على التكليف السابق
  Future<Map<String, String?>> _getPreviousAssignment(String studentId) async {
    try {
      final previousSessions = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('studentId', isEqualTo: studentId)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();

      if (previousSessions.docs.isEmpty) {
        return {'hifz': null, 'muraja': null};
      }

      final data = previousSessions.docs.first.data();
      return {
        'hifz': data['hifzAssignment'] as String?,
        'muraja': data['murajaAssignment'] as String?,
      };
    } catch (e) {
      return {'hifz': null, 'muraja': null};
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentName = session['studentName'] as String? ?? 'غير معروف';
    final sessionDate = session['sessionDate'] as DateTime?;
    final timeSlot = session['preferredTimeSlot'] as String? ?? '08:00';
    final location = session['location'] as String? ?? '';
    final sessionType = session['sessionType'] as String? ?? '';
    final studentId = session['studentId'] as String? ?? '';

    // Calculate days until session
    String getTimeUntil() {
      if (sessionDate == null) return '';

      final now = DateTime.now();
      final dateOnly = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final difference = dateOnly.difference(today).inDays;

      if (difference == 0) {
        return 'اليوم';
      } else if (difference == 1) {
        return 'غداً';
      } else if (difference <= 7) {
        return 'بعد $difference أيام';
      } else {
        return 'بعد ${(difference / 7).floor()} أسابيع';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // يمكن فتح تفاصيل الجلسة إذا لزم الأمر
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppTheme.accentGreen,
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
                        Text(
                          sessionType,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time Until Badge
                  if (sessionDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        getTimeUntil(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAmber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Date & Time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    sessionDate != null
                        ? DateFormat('EEEE dd MMMM yyyy', 'ar').format(sessionDate)
                        : 'غير محدد',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    timeSlot,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ✅ زر إكمال الجلسة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // جلب التكليف السابق
                    final previousAssignment = await _getPreviousAssignment(studentId);

                    if (!context.mounted) return;

                    // فتح شاشة الإكمال
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionCompletionScreen(
                          sessionId: session['id'] as String,
                          studentName: studentName,
                          previousHifz: previousAssignment['hifz'],
                          previousMuraja: previousAssignment['muraja'],
                        ),
                      ),
                    );

                    // تحديث القائمة بعد الإكمال
                    if (result == true && context.mounted) {
                      ref.invalidate(upcomingSessionsProvider(mohaffezId));
                      ref.invalidate(completedSessionsProvider(mohaffezId));
                    }
                  },
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    'إكمال الجلسة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
