// screens/upcoming_sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../utils/arabic_labels.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'session_completion_screen.dart';

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
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(upcomingSessionsProvider(mohaffezId));
            await ref
                .read(upcomingSessionsProvider(mohaffezId).future)
                .catchError((_) => <Map<String, dynamic>>[]);
          },
          child: CustomScrollView(
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ArabicLabels.upcomingSessions,
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
                              ref
                                  .read(upcomingSessionsFilterProvider.notifier)
                                  .state = UpcomingFilter.all;
                            },
                            selectedColor:
                                AppTheme.accentGreen.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.accentGreen,
                          ),
                          FilterChip(
                            label: const Text('اليوم'),
                            selected: filter == UpcomingFilter.today,
                            onSelected: (_) {
                              ref
                                  .read(upcomingSessionsFilterProvider.notifier)
                                  .state = UpcomingFilter.today;
                            },
                            selectedColor:
                                AppTheme.accentGreen.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.accentGreen,
                          ),
                          FilterChip(
                            label: const Text('هذا الأسبوع'),
                            selected: filter == UpcomingFilter.thisWeek,
                            onSelected: (_) {
                              ref
                                  .read(upcomingSessionsFilterProvider.notifier)
                                  .state = UpcomingFilter.thisWeek;
                            },
                            selectedColor:
                                AppTheme.accentGreen.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.accentGreen,
                          ),
                          FilterChip(
                            label: const Text('هذا الشهر'),
                            selected: filter == UpcomingFilter.thisMonth,
                            onSelected: (_) {
                              ref
                                  .read(upcomingSessionsFilterProvider.notifier)
                                  .state = UpcomingFilter.thisMonth;
                            },
                            selectedColor:
                                AppTheme.accentGreen.withValues(alpha: 0.2),
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
                            ref
                                .read(upcomingSessionsFilterProvider.notifier)
                                .state = UpcomingFilter.all;
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
      ),
    );
  }
}

// ============================================================================
// SESSION CARD WIDGET - With Complete Workflow
// ============================================================================

class SessionCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final String mohaffezId;

  const SessionCard({
    super.key,
    required this.session,
    required this.mohaffezId,
  });

  // ✅ Check if session can be completed (30 min before → 24 hours after)
  bool _canCompleteSession(DateTime sessionDate, String timeSlot) {
    try {
      final now = DateTime.now();

      // Parse time slot (e.g., "08:00" or "08:00-09:00")
      final timeParts = timeSlot.split('-')[0].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      // Actual session time
      final sessionTime = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        hour,
        minute,
      );

      // Window: 30 min before → 24 hours after
      final canStartFrom = sessionTime.subtract(const Duration(minutes: 30));
      final canCompleteUntil = sessionTime.add(const Duration(hours: 24));

      return now.isAfter(canStartFrom) && now.isBefore(canCompleteUntil);
    } catch (e) {
      return false;
    }
  }

  // ✅ Check if session is late (more than 15 min after scheduled time)
  bool _isSessionLate(DateTime sessionDate, String timeSlot) {
    try {
      final now = DateTime.now();
      final timeParts = timeSlot.split('-')[0].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      final sessionTime = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        hour,
        minute,
      );

      final lateThreshold = sessionTime.add(const Duration(minutes: 15));
      return now.isAfter(lateThreshold);
    } catch (e) {
      return false;
    }
  }

  // ✅ Get previous assignment
  Future<Map<String, dynamic>> _getPreviousAssignment(String studentId) async {
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

  // ✅ Mark as No-Show
  Future<void> _markAsNoShow(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoShowReasonDialog(),
    );

    if (reason == null) return; // User cancelled

    try {
      await FirebaseFirestore.instance
          .collection('hafizSessions')
          .doc(session['id'] as String)
          .update({
        'status': 'no-show',
        'noShowReason': reason,
        'noShowMarkedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل عدم الحضور'),
          backgroundColor: Colors.orange,
        ),
      );

      ref.invalidate(upcomingSessionsProvider(mohaffezId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _showCancelSessionDialog(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String partnerName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(ArabicLabels.cancelSession),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من إلغاء هذه الجلسة مع $partnerName؟',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إعادة الوقت للمحفظ ليتمكن طلاب آخرون من الحجز',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('نعم، إلغاء الجلسة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري إلغاء الجلسة...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await ref.read(sessionActionsProvider.notifier).cancelSession(sessionId);

      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('تم إلغاء الجلسة بنجاح'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      ref.invalidate(upcomingSessionsProvider(mohaffezId));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('فشل إلغاء الجلسة: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف غير متوفر')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final whatsappUrl =
        Uri.parse('https://wa.me/$cleanPhone?text=السلام عليكم');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل فتح واتساب')),
      );
    }
  }

  Future<void> _callTeacher(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف غير متوفر')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final telUrl = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(telUrl)) {
      await launchUrl(telUrl);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل فتح تطبيق الهاتف')),
      );
    }
  }

  Future<void> _openMaps(BuildContext context, String? address) async {
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العنوان غير متوفر')),
      );
      return;
    }
    final encodedAddress = Uri.encodeComponent(address);
    final mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل فتح خرائط جوجل')),
      );
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
    final mohaffezPhone = session['mohaffezPhone'] as String? ??
        session['teacherPhone'] as String?;
    final locationAddress =
        session['imamAddressText'] as String? ?? session['location'] as String?;

    final bool canComplete =
        sessionDate != null && _canCompleteSession(sessionDate, timeSlot);
    final bool isLate =
        sessionDate != null && _isSessionLate(sessionDate, timeSlot);
    final hoursUntilSession =
        sessionDate?.difference(DateTime.now()).inHours ?? 999;
    final showCommunication =
        hoursUntilSession <= 24 && hoursUntilSession >= -2;

    // Calculate days until session
    String getTimeUntil() {
      if (sessionDate == null) return '';
      final now = DateTime.now();
      final dateOnly =
          DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
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
          // Can show session details if needed
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
                  // Status Badge
                  if (sessionDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: canComplete
                            ? AppTheme.accentGreen.withValues(alpha: 0.1)
                            : AppTheme.primaryAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: canComplete
                              ? AppTheme.accentGreen.withValues(alpha: 0.3)
                              : AppTheme.primaryAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        canComplete ? 'جاهزة' : getTimeUntil(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: canComplete
                              ? AppTheme.accentGreen
                              : AppTheme.primaryAmber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Date & Time
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    sessionDate != null
                        ? DateFormat('EEEE dd MMMM yyyy', 'ar')
                            .format(sessionDate)
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
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade600),
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
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade600),
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
              if (showCommunication) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message, size: 20),
                        label: const Text('مراسلة',
                            style: TextStyle(fontSize: 14)),
                        onPressed:
                            (mohaffezPhone == null || mohaffezPhone.isEmpty)
                                ? null
                                : () => _openWhatsApp(context, mohaffezPhone),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone, size: 20),
                        label:
                            const Text('اتصال', style: TextStyle(fontSize: 14)),
                        onPressed:
                            (mohaffezPhone == null || mohaffezPhone.isEmpty)
                                ? null
                                : () => _callTeacher(context, mohaffezPhone),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.location_on, size: 20),
                        label: const Text('الموقع',
                            style: TextStyle(fontSize: 14)),
                        onPressed: () => _openMaps(context, locationAddress),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: ArabicLabels.cancelSession,
                  onPressed: () => _showCancelSessionDialog(
                    context,
                    ref,
                    session['id'] as String,
                    session['studentName'] as String? ?? 'الطالب',
                  ),
                ),
              ),

              // ✅ ACTION BUTTONS - Based on Session Time
              if (canComplete) ...[
                // Session is ACTIVE - Can complete
                Row(
                  children: [
                    // No-Show Button (if late)
                    if (isLate)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _markAsNoShow(context, ref),
                          icon: const Icon(Icons.person_off, size: 18),
                          label: const Text('لم يحضر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (isLate) const SizedBox(width: 8),
                    // Complete Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Fetch previous assignment
                          final previousAssignment =
                              await _getPreviousAssignment(studentId);
                          if (!context.mounted) return;

                          // Open completion screen
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionCompletionScreen(
                                sessionId: session['id'] as String,
                                studentName: studentName,
                                previousHifz: previousAssignment['hifz'],
                                previousMuraja: previousAssignment['muraja'],
                                isLateCompletion: isLate,
                              ),
                            ),
                          );

                          // Refresh lists if completed
                          if (result == true && context.mounted) {
                            ref.invalidate(
                                upcomingSessionsProvider(mohaffezId));
                            ref.invalidate(
                                completedSessionsProvider(mohaffezId));
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: Text(
                          isLate ? 'إكمال متأخر' : 'إكمال الجلسة',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isLate ? Colors.orange : AppTheme.accentGreen,
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
              ] else ...[
                // Session is SCHEDULED - Too early to complete
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يمكن إكمال الجلسة قبل الموعد بـ 30 دقيقة',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NO-SHOW REASON DIALOG
// ============================================================================

class _NoShowReasonDialog extends StatefulWidget {
  @override
  State<_NoShowReasonDialog> createState() => _NoShowReasonDialogState();
}

class _NoShowReasonDialogState extends State<_NoShowReasonDialog> {
  final reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('سبب عدم الحضور'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اختياري: يمكنك توضيح سبب عدم حضور الطالب',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
