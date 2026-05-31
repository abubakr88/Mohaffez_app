// screens/upcoming_sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/time_formatter.dart';
import '../../shared/widgets/error_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/meeting_launcher_service.dart';

class UpcomingSessionsScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final UpcomingFilter initialFilter;

  const UpcomingSessionsScreen({
    super.key,
    required this.mohaffezId,
    this.initialFilter = UpcomingFilter.all,
  });

  @override
  ConsumerState<UpcomingSessionsScreen> createState() =>
      _UpcomingSessionsScreenState();
}

class _UpcomingSessionsScreenState extends ConsumerState<UpcomingSessionsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != UpcomingFilter.all) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(upcomingSessionsFilterProvider.notifier).state =
            widget.initialFilter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mohaffezId = widget.mohaffezId;
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
                                    color: AppThemeConstants.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event_available,
                                    size: 28,
                                    color: AppThemeConstants.white,
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
                                          color: AppThemeConstants.white,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'جلساتك المجدولة',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppThemeConstants.white70,
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
                                      color: AppThemeConstants.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      sessions.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppThemeConstants.secondary,
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
                                AppThemeConstants.secondary.withValues(alpha: 0.2),
                            checkmarkColor: AppThemeConstants.secondary,
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
                                AppThemeConstants.secondary.withValues(alpha: 0.2),
                            checkmarkColor: AppThemeConstants.secondary,
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
                                AppThemeConstants.secondary.withValues(alpha: 0.2),
                            checkmarkColor: AppThemeConstants.secondary,
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
                                AppThemeConstants.secondary.withValues(alpha: 0.2),
                            checkmarkColor: AppThemeConstants.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filtered Count
                      Text(
                        'عدد الجلسات: ${filteredSessions.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.grey600,
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
                    return SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.event_busy,
                        title: 'لا توجد جلسات قادمة',
                        message: 'لم يتم جدولة أي جلسات بعد',
                        animated: true,
                        action: TextButton.icon(
                          onPressed: () {
                            ref.invalidate(upcomingSessionsProvider(mohaffezId));
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث'),
                        ),
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

  Future<void> _showMissingMeetingLinkDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('أضف رابط الاجتماع أولاً',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'لم تقم بإضافة رابط Zoom أو Google Meet في ملفك الشخصي. أضفه مرة واحدة وسيُستخدم لجميع جلساتك أونلاين.',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لاحقاً'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/profile');
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('فتح الملف الشخصي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Check if session can be completed (30 min before → 24 hours after)
  bool _canCompleteSession(DateTime sessionDate, String timeSlot, int earlyMinutes, WidgetRef ref) {
    try {
      final now = serverNow(ref);

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
      final canStartFrom = sessionTime.subtract(Duration(minutes: earlyMinutes));
      final canCompleteUntil = sessionTime.add(const  Duration(hours: 24));

      return now.isAfter(canStartFrom) && now.isBefore(canCompleteUntil);
    } catch (e) {
      return false;
    }
  }

  // ✅ Check if session is late (more than 15 min after scheduled time)
  bool _isSessionLate(DateTime sessionDate, String timeSlot, WidgetRef ref) {
    try {
      final now = serverNow(ref);
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
        'hifzFromAyah': data['hifzFromAyah'] as String?,
        'hifzToAyah': data['hifzToAyah'] as String?,
        'murajaFromAyah': data['murajaFromAyah'] as String?,
        'murajaToAyah': data['murajaToAyah'] as String?,
      };
    } catch (e) {
      return {'hifz': null, 'muraja': null};
    }
  }

  // ✅ Mark as No-Show
  Future<void> _markAsNoShow(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_off, color: AppThemeConstants.warning),
            SizedBox(width: 8),
            Text('تسجيل غياب الطالب'),
          ]),
          content: const Text(
            'هل أنت متأكد أن الطالب لم يحضر؟ سيُسجَّل تحذير على حسابه وتحتسب الجلسة كمكتملة لك.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.warning),
              child: const Text('تأكيد الغياب', style: TextStyle(color: AppThemeConstants.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('onStudentNoShowReported')
          .call({'sessionId': session['id'] as String});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل عدم الحضور'),
          backgroundColor: AppThemeConstants.warning,
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
    String partnerName, {
    DateTime? sessionDate,
    String? paymentType,
    double? sessionPrice,
    String? subscriptionId,
  }) async {
    // Bundle session: no money moves on cancel. Student's bundle gets the
    // session credit back (or loses it on late student cancel). Teacher still
    // pays commission penalty on top, if any.
    // Single session: full amount is returned to student from the teacher's
    // earnings (pending/available for wallet, dues for direct payment).
    final isBundle = subscriptionId != null ||
        paymentType == 'bundle' ||
        paymentType == 'subscription';
    final priceText = (sessionPrice != null && sessionPrice > 0)
        ? '${sessionPrice.toStringAsFixed(0)} ج.م '
        : '';
    final hoursUntil = sessionDate != null
        ? sessionDate.difference(serverNow(ref)).inHours
        : 999;
    String? penaltyText;
    if (hoursUntil < 1) {
      penaltyText = 'بالإضافة إلى زيادة عمولة المنصة بـ 1% لهذه الدورة';
    } else if (hoursUntil < 3) {
      penaltyText = 'بالإضافة إلى زيادة عمولة المنصة بـ 0.5% لهذه الدورة';
    }
    final headlineText = isBundle
        ? 'لن يتم تحويل أموال — ستُعاد الحلقة إلى رصيد باقة الطالب'
        // ignore: unnecessary_brace_in_string_interps
        : 'كامل المبلغ ${priceText}سيُخصم من أرباحك ويُعاد إلى محفظة الطالب';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppThemeConstants.warning, size: 28),
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
                  color: AppThemeConstants.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemeConstants.error),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: AppThemeConstants.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headlineText,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppThemeConstants.error,
                                fontWeight: FontWeight.w600),
                          ),
                          if (penaltyText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              penaltyText,
                              style: const TextStyle(
                                  fontSize: 12, color: AppThemeConstants.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.accentBlueLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemeConstants.accentBlue),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppThemeConstants.accentBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إعادة الوقت للمحفظ ليتمكن طلاب آخرون من الحجز',
                        style: TextStyle(fontSize: 13, color: AppThemeConstants.accentBlue),
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
                backgroundColor: AppThemeConstants.error,
                foregroundColor: AppThemeConstants.white,
              ),
              child: const Text('نعم، إلغاء الجلسة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Capture the root navigator + messenger before the async gap. The
    // Firestore realtime listener may unmount this SessionCard before the
    // Cloud Function returns, invalidating `context`.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Push the loading dialog as a DialogRoute we hold a reference to, then
    // remove it explicitly via `removeRoute`. `Navigator.pop()` is unsafe here
    // because when SessionCard unmounts, the dialog (anchored to its context)
    // may be torn down with it — a subsequent pop() would then pop the actual
    // page underneath, crashing GoRouter with "no pages left to show".
    final loadingRoute = DialogRoute<void>(
      // ignore: use_build_context_synchronously
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => const Center(
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
    navigator.push(loadingRoute);

    void dismissLoading() {
      if (loadingRoute.isActive) {
        navigator.removeRoute(loadingRoute);
      }
    }

    try {
      await ref.read(sessionActionsProvider.notifier).cancelSession(sessionId, cancelledBy: 'teacher');

      dismissLoading();
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppThemeConstants.white),
              SizedBox(width: 12),
              Text('تم إلغاء الجلسة بنجاح'),
            ],
          ),
          backgroundColor: AppThemeConstants.success,
          duration: Duration(seconds: 3),
        ),
      );
      // No `ref.invalidate` here — upcomingSessionsProvider is a stream, so
      // the Firestore listener has already pushed the updated list and this
      // SessionCard is being disposed. Touching `ref` after disposal throws
      // "Bad state: Cannot use 'ref' after the widget was disposed", which
      // would surface as a misleading "cancel failed" snackbar.
    } catch (e) {
      dismissLoading();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppThemeConstants.white),
              const SizedBox(width: 12),
              Expanded(child: Text('فشل إلغاء الجلسة: ${e.toString()}')),
            ],
          ),
          backgroundColor: AppThemeConstants.error,
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
    final earlyMinutes = ref
        .watch(systemConfigProvider)
        .valueOrNull
        ?.meetingStartLeadTimeMinutes ?? 60;
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
        sessionDate != null && _canCompleteSession(sessionDate, timeSlot, earlyMinutes, ref);
    final bool isLate =
        sessionDate != null && _isSessionLate(sessionDate, timeSlot, ref);
    final hoursUntilSession =
        sessionDate?.difference(serverNow(ref)).inHours ?? 999;
    final showCommunication =
        hoursUntilSession <= 24 && hoursUntilSession >= -2;

    // Calculate days until session
    String getTimeUntil() {
      if (sessionDate == null) return '';
      final now = serverNow(ref);
      final dateOnly =
          DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final difference = dateOnly.difference(today).inDays;

      if (difference == 0) {
        return 'اليوم';
      } else if (difference == 1) {
        return 'غداً';
      } else if (difference == 2) {
        return 'بعد يومين';
      } else if (difference >= 3 && difference <= 10) {
        return 'بعد $difference أيام';
      } else if (difference > 10) {
        return 'بعد $difference يوم';
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
                      color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppThemeConstants.secondary,
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.grey600,
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
                            ? AppThemeConstants.secondary.withValues(alpha: 0.1)
                            : AppThemeConstants.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: canComplete
                              ? AppThemeConstants.secondary.withValues(alpha: 0.3)
                              : AppThemeConstants.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        canComplete ? 'جاهزة' : getTimeUntil(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: canComplete
                              ? AppThemeConstants.secondary
                              : AppThemeConstants.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Date & Time
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppThemeConstants.grey600),
                  const SizedBox(width: 6),
                  Text(
                    sessionDate != null
                        ? DateFormat('EEEE dd MMMM yyyy', 'ar')
                            .format(sessionDate)
                        : 'غير محدد',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppThemeConstants.grey700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppThemeConstants.grey600),
                  const SizedBox(width: 6),
                  Text(
                    formatTimeToArabicAmPm(timeSlot),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppThemeConstants.grey700,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on,
                        size: 14, color: AppThemeConstants.grey600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.grey700,
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
                          foregroundColor: AppThemeConstants.success,
                          side: const BorderSide(color: AppThemeConstants.success),
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
                          foregroundColor: AppThemeConstants.accentBlue,
                          side: const BorderSide(color: AppThemeConstants.accentBlue),
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
                          foregroundColor: AppThemeConstants.error,
                          side: const BorderSide(color: AppThemeConstants.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('إلغاء الجلسة'),
                  onPressed: () => _showCancelSessionDialog(
                    context,
                    ref,
                    session['id'] as String,
                    session['studentName'] as String? ?? 'الطالب',
                    sessionDate: sessionDate,
                    paymentType: session['paymentType'] as String?,
                    sessionPrice: (session['sessionPrice'] as num?)?.toDouble(),
                    subscriptionId: session['subscriptionId'] as String?,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeConstants.error,
                    side: const BorderSide(color: AppThemeConstants.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // ✅ ACTION BUTTONS - Online sessions get a dedicated start button
              // gated by lead-time guard + concurrent-session guard inside
              // markMeetingStarted. Other session types stay gated by canComplete.
              if (sessionType == 'online') ...[
                _TeacherStartSessionButton(
                  sessionId: session['id'] as String,
                  mohaffezId: mohaffezId,
                  onAfterStart: () async {
                    final previousAssignment =
                        await _getPreviousAssignment(studentId);
                    if (!context.mounted) return;
                    final result = await context.push<bool>(
                      '/complete-session/${session['id'] as String}',
                      extra: {
                        'studentName': studentName,
                        'previousHifz': previousAssignment['hifz'],
                        'previousMuraja': previousAssignment['muraja'],
                        'previousHifzFromAyah': previousAssignment['hifzFromAyah'],
                        'previousHifzToAyah': previousAssignment['hifzToAyah'],
                        'previousMurajaFromAyah': previousAssignment['murajaFromAyah'],
                        'previousMurajaToAyah': previousAssignment['murajaToAyah'],
                        'isLateCompletion': isLate,
                        'sessionType': sessionType,
                      },
                    );
                    if (result == true && context.mounted) {
                      ref.invalidate(upcomingSessionsProvider(mohaffezId));
                      ref.invalidate(completedSessionsProvider(mohaffezId));
                    }
                  },
                  onMissingLink: () => _showMissingMeetingLinkDialog(context),
                ),
              ] else if (canComplete) ...[
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
                            foregroundColor: AppThemeConstants.warning,
                            side: const BorderSide(color: AppThemeConstants.warning),
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
                          final result = await context.push<bool>(
                            '/complete-session/${session['id'] as String}',
                            extra: {
                              'studentName': studentName,
                              'previousHifz': previousAssignment['hifz'],
                              'previousMuraja': previousAssignment['muraja'],
                              'previousHifzFromAyah': previousAssignment['hifzFromAyah'],
                              'previousHifzToAyah': previousAssignment['hifzToAyah'],
                              'previousMurajaFromAyah': previousAssignment['murajaFromAyah'],
                              'previousMurajaToAyah': previousAssignment['murajaToAyah'],
                              'isLateCompletion': isLate,
                            },
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
                              isLate ? AppThemeConstants.warning : AppThemeConstants.secondary,
                          foregroundColor: AppThemeConstants.white,
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
                    color: AppThemeConstants.accentBlueLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeConstants.accentBlue),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 20, color: AppThemeConstants.accentBlueDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يمكن إكمال الجلسة قبل الموعد بـ $earlyMinutes دقيقة',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.accentBlueDark,
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
/// Teacher's "ابدأ الجلسة" button. Reads `meetingButtonStateProvider` so it
/// disables itself before `sessionDate − leadTime` and changes label after
/// the teacher has clicked start. All the actual work of writing
/// `meetingStartedAt` (with lead-time + concurrent-session guards) lives in
/// `MeetingLauncherService.markMeetingStarted`.
class _TeacherStartSessionButton extends ConsumerWidget {
  final String sessionId;
  final String mohaffezId;
  final Future<void> Function() onAfterStart;
  final Future<void> Function() onMissingLink;

  const _TeacherStartSessionButton({
    required this.sessionId,
    required this.mohaffezId,
    required this.onAfterStart,
    required this.onMissingLink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meetingButtonStateProvider(
        (sessionId: sessionId, role: 'mohaffez')));
    final infoAsync = ref.watch(meetingInfoProvider(sessionId));
    final info = infoAsync.valueOrNull;
    final leadTimeMinutes = ref
            .watch(systemConfigProvider)
            .valueOrNull
            ?.meetingStartLeadTimeMinutes ??
        60;

    String label;
    IconData icon;
    bool enabled;

    switch (state) {
      case MeetingButtonState.tooEarly:
        final sd = info?.slotStart ?? info?.sessionDate;
        String countdown = '';
        if (sd != null) {
          final earliestStart =
              sd.subtract(Duration(minutes: leadTimeMinutes));
          final diff = earliestStart.difference(DateTime.now());
          if (diff.inHours > 0) {
            countdown =
                ' (يمكنك البدء بعد ${diff.inHours}س ${diff.inMinutes.remainder(60)}د)';
          } else if (diff.inMinutes > 0) {
            countdown = ' (يمكنك البدء بعد ${diff.inMinutes}د)';
          }
        }
        label = 'لم يحن وقت الجلسة بعد$countdown';
        icon = Icons.lock_clock_rounded;
        enabled = false;
        break;
      case MeetingButtonState.inProgress:
        label = 'تم بدء الجلسة — متابعة';
        icon = Icons.open_in_new_rounded;
        enabled = true;
        break;
      case MeetingButtonState.ended:
      case MeetingButtonState.teacherLate:
        label = 'انتهت';
        icon = Icons.videocam_off_rounded;
        enabled = false;
        break;
      case MeetingButtonState.pendingMeetingLink:
      case MeetingButtonState.hidden:
      case MeetingButtonState.waitingForTeacher:
      case MeetingButtonState.ready:
        label = 'ابدأ الجلسة';
        icon = Icons.videocam_rounded;
        enabled = state != MeetingButtonState.pendingMeetingLink;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => _onTap(context, ref) : null,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: state == MeetingButtonState.inProgress
              ? AppThemeConstants.success
              : AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final leadTimeMinutes = ref
            .read(systemConfigProvider)
            .valueOrNull
            ?.meetingStartLeadTimeMinutes ??
        60;
    final result = await MeetingLauncherService.markMeetingStarted(
      sessionId: sessionId,
      teacherId: mohaffezId,
      leadTimeMinutes: leadTimeMinutes,
    );
    if (!context.mounted) return;
    if (result.error != null) {
      switch (result.error) {
        case 'noLink':
          await onMissingLink();
          return;
        case 'tooEarly':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppThemeConstants.warning,
              content: Text(
                'لا يمكن بدء الجلسة قبل موعدها بأكثر من $leadTimeMinutes دقيقة',
              ),
            ),
          );
          return;
        case 'concurrent':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppThemeConstants.error,
              content: Text(
                'لديك جلسة أخرى مفتوحة بالفعل — أنهِها قبل بدء جلسة جديدة',
              ),
            ),
          );
          return;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppThemeConstants.error,
              content: Text('تعذّر بدء الجلسة، حاول مرة أخرى'),
            ),
          );
          return;
      }
    }
    await onAfterStart();
  }
}
