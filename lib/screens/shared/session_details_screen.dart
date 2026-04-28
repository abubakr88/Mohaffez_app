// lib/screens/session_details_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/session_model.dart';
import '../../models/quran_mistake_model.dart';
import '../../shared/utils/quran_mistake_utils.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../providers/user_provider.dart';
import '../../providers/session_provider_paginated.dart';
import '../../shared/widgets/interactive_quran_page.dart';
import '../student/rate_session_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
class SessionDetailsScreen extends ConsumerStatefulWidget {
  final SessionModel session;
  const SessionDetailsScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailsScreen> createState() =>
      _SessionDetailsScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  // Quran mistakes state
  List<QuranMistake> loadedMistakes = [];
  bool mistakesLoading = true;
  int moshafStartPage = 1;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loadQuranMistakes(); // fire-and-forget — fine in initState
  }

  // ── Fetch mistakes ─────────────────────────────────────────────────────────
  // Mistakes may already be embedded in session.mistakes (teacher view) or need
  // to be fetched fresh from the hafizSessions document (student view).
  Future<void> loadQuranMistakes() async {
    final sessionId = widget.session.id;
    if (sessionId == null || sessionId.isEmpty) {
      if (mounted) setState(() => mistakesLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .doc(sessionId)
          .get();

      final data = doc.data();
      if (data != null) {
        final raw = data['mistakes'];
        if (raw is List && raw.isNotEmpty) {
          final mistakes = raw
              .whereType<Map<String, dynamic>>()
              .map(QuranMistake.fromMap)
              .toList();
          if (mistakes.isNotEmpty) {
            if (mounted) {
              setState(() {
                loadedMistakes = mistakes;
                moshafStartPage = mistakes.first.pageNumber;
                mistakesLoading = false;
              });
            }
            return;
          }
        }
      }

      // Fallback: use the mistakes already embedded in the session object
      if (widget.session.mistakes.isNotEmpty) {
        if (mounted) {
          setState(() {
            loadedMistakes = widget.session.mistakes;
            moshafStartPage = widget.session.mistakes.first.pageNumber;
            mistakesLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => mistakesLoading = false);
      }
    } catch (e) {
      debugPrint('SessionDetails: loadQuranMistakes error: $e');
      if (widget.session.mistakes.isNotEmpty) {
        if (mounted) {
          setState(() {
            loadedMistakes = widget.session.mistakes;
            moshafStartPage = widget.session.mistakes.first.pageNumber;
          });
        }
      }
      if (mounted) setState(() => mistakesLoading = false);
    }
  }

  Future<void> refreshScreen() async {
    if (mounted) setState(() => mistakesLoading = true);
    await loadQuranMistakes();
  }

  // ── Open read-only Mushaf ──────────────────────────────────────────────────
  void openReadOnlyMoshaf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              leading: context.canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: context.pop,
                      tooltip: 'رجوع',
                    )
                  : null,
              title: const Text('مراجعة التلاوة'),
              backgroundColor: AppThemeConstants.success,
              foregroundColor: AppThemeConstants.white,
            ),
            body: InteractiveQuranPage(
              pageNumber: moshafStartPage,
              existingMistakes: loadedMistakes,
              onMistakeAdded: (_) {}, // read-only — no-op
              isEditable: false,
              onPageChanged: (p) {
                if (mounted) setState(() => moshafStartPage = p);
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Cancellation dialog ────────────────────────────────────────────────────
  Future<void> showCancellationDialog(
    SessionModel session,
    String? precalculatedRefundPolicy,
  ) async {
    final hoursUntilSession =
        session.sessionDate!.difference(DateTime.now()).inHours;

    final String refundPolicy;
    final Color policyColor;

    if (hoursUntilSession >= 24) {
      refundPolicy = 'استرداد كامل للمبلغ';
      policyColor = AppThemeConstants.success;
    } else if (hoursUntilSession >= 2) {
      refundPolicy = 'استرداد جزئي 50% من المبلغ';
      policyColor = AppThemeConstants.warning;
    } else {
      refundPolicy = 'لا يوجد استرداد للمبلغ';
      policyColor = AppThemeConstants.error;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppThemeConstants.error),
              SizedBox(width: 8),
              Text('إلغاء الجلسة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'هل أنت متأكد أنك تريد إلغاء هذه الجلسة؟',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: policyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: policyColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: policyColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        refundPolicy,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: policyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text(
                'تأكيد الإلغاء',
                style: TextStyle(color: AppThemeConstants.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جارٍ الإلغاء...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final sessionId = session.id;
      if (sessionId == null) throw Exception('معرّف الجلسة غير موجود');
      await ref.read(sessionActionsProvider.notifier).cancelSession(sessionId);
      if (mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // close session details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الجلسة بنجاح'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  // ── Navigate to rating ─────────────────────────────────────────────────────
  Future<void> navigateToRating(SessionModel session) async {
    final sessionId = session.id;
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر تحديد الجلسة'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateSessionScreen(
          sessionId: sessionId,
          mohaffezName: session.mohaffezName,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شكراً على تقييمك!'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    }
  }

  // ── Label helpers ──────────────────────────────────────────────────────────
  String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'مقبولة';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'awaitingpayment':
        return 'بانتظار الدفع';
      default:
        return status;
    }
  }

  String getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'في المنزل';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return AppThemeConstants.success;
      case 'pending':
        return AppThemeConstants.warning;
      case 'completed':
        return AppThemeConstants.accentBlue;
      case 'cancelled':
        return AppThemeConstants.error;
      default:
        return AppThemeConstants.grey500;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isMohaffez = currentUser?.role == 'mohaffez';
    final isStudent = currentUser?.role == 'student';
    final session = widget.session;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: refreshScreen,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 160,
                floating: true,
                pinned: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'session_${session.id}',
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          AppThemeConstants.white.withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.school,
                                      size: 32,
                                      color: AppThemeConstants.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMohaffez
                                            ? session.studentName
                                            : session.mohaffezName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppThemeConstants.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppThemeConstants.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          getStatusLabel(
                                              session.status ?? ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppThemeConstants.white,
                                          ),
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
              ),

              // ── Content ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Session Info
                    _SectionCard(
                      title: 'معلومات الجلسة',
                      icon: Icons.info_outline,
                      color: AppThemeConstants.accentBlue,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.event,
                            label: 'نوع الجلسة',
                            value: getSessionTypeLabel(session.sessionType),
                          ),
                          if (session.preferredTimeSlot != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.access_time,
                              label: 'الوقت',
                              value: session.preferredTimeSlot!,
                            ),
                          ],
                          if (session.sessionDate != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'التاريخ',
                              value: DateFormat('dd MMMM yyyy', 'ar')
                                  .format(session.sessionDate!),
                            ),
                          ],
                          if (session.location.isNotEmpty) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'الموقع',
                              value: session.location,
                            ),
                          ],
                          if (session.currentPage != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.auto_stories,
                              label: 'الصفحة الحالية',
                              value: '${session.currentPage}',
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Assignments
                    if ((session.hifzAssignment?.isNotEmpty ?? false) ||
                        (session.murajaAssignment?.isNotEmpty ?? false))
                      _SectionCard(
                        title: 'الواجبات',
                        icon: Icons.assignment,
                        color: AppThemeConstants.secondary,
                        child: Column(
                          children: [
                            if (session.hifzAssignment?.isNotEmpty ??
                                false)
                              _AssignmentCard(
                                icon: Icons.menu_book,
                                color: AppThemeConstants.success,
                                label: 'حفظ',
                                value: session.hifzAssignment!,
                              ),
                            if (session.murajaAssignment?.isNotEmpty ??
                                false)
                              _AssignmentCard(
                                icon: Icons.refresh,
                                color: AppThemeConstants.accentBlue,
                                label: 'مراجعة',
                                value: session.murajaAssignment!,
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Performance notes (completed sessions)
                    if (session.status == 'completed' &&
                        (session.performanceNotes?.isNotEmpty ?? false))
                      _SectionCard(
                        title: 'ملاحظات الأداء',
                        icon: Icons.note,
                        color: AppThemeConstants.accentPurple,
                        child: Text(
                          session.performanceNotes!,
                          style: const TextStyle(
                              fontSize: 15, height: 1.6),
                        ),
                      ),

                    if (session.status == 'completed' &&
                        (session.sessionNotes?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'ملاحظات الجلسة',
                        icon: Icons.notes,
                        color: AppThemeConstants.grey600,
                        child: Text(
                          session.sessionNotes!,
                          style: const TextStyle(
                              fontSize: 15, height: 1.6),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Quran Mistakes Section
                    buildQuranMistakesSection(
                        // ignore: dead_null_aware_expression
                        isMohaffez: isMohaffez ?? false),

                    const SizedBox(height: 16),

                    // Mushaf button — only when mistakes exist (Fix #3)
                    if (loadedMistakes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: buildMoshafButton,
                      ),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: buildBottomNavigationBar(
          isMohaffez: isMohaffez,
          isStudent: isStudent,
          session: session,
        ),
      ),
    );
  }

  // ── Quran Mistakes Section ─────────────────────────────────────────────────
  Widget buildQuranMistakesSection({required bool isMohaffez}) {
    if (mistakesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (loadedMistakes.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'الأخطاء القرآنية',
      icon: Icons.menu_book,
      color: AppThemeConstants.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMistakeStatsRow,
          const SizedBox(height: 16),
          buildTypeBreakdownChips,
          const Divider(height: 28),
          // Teacher: full list grouped by page
          if (isMohaffez) buildGroupedMistakeList,
          // Student: flat summary tiles, tap to see detail
          if (!isMohaffez) buildStudentMistakeTiles,
        ],
      ),
    );
  }

  // Stats row: total | with-comment | pages
  Widget get buildMistakeStatsRow {
    final withComment = countWithComments(loadedMistakes);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.accentGreenAlt),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCell(
            icon: Icons.warning_amber_rounded,
            color: AppThemeConstants.warning,
            label: 'مجموع الأخطاء',
            value: loadedMistakes.length,
          ),
          Container(
              width: 1, height: 36, color: AppThemeConstants.accentGreenAlt),
          _StatCell(
            icon: Icons.chat_bubble,
            color: AppThemeConstants.accentBlueDark,
            label: 'مع تعليق',
            value: withComment,
          ),
          Container(
              width: 1, height: 36, color: AppThemeConstants.accentGreenAlt),
          _StatCell(
            icon: Icons.auto_stories,
            color: AppThemeConstants.success,
            label: 'صفحات',
            value: loadedMistakes.map((m) => m.pageNumber).toSet().length,
          ),
        ],
      ),
    );
  }

  // Chips: one per mistake type with count
  Widget get buildTypeBreakdownChips {
    final groups = groupMistakesByType(loadedMistakes);
    if (groups.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: groups.entries.map((e) {
        return Chip(
          avatar: Icon(getMistakeIcon(e.key), size: 14, color: AppThemeConstants.white),
          label: Text(
            '${e.key.arabicLabel}  ${e.value}',
            style: const TextStyle(fontSize: 11, color: AppThemeConstants.white),
          ),
          backgroundColor: getMistakeColor(e.key),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  // Teacher: ExpansionTile grouped by page
  Widget get buildGroupedMistakeList {
    final pages =
        loadedMistakes.map((m) => m.pageNumber).toSet().toList()..sort();
    return Column(
      children: pages.map((page) {
        final pageMistakes = getMistakesOnPage(loadedMistakes, page);
        return Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: AppThemeConstants.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemeConstants.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ص $page',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.successDark,
                ),
              ),
            ),
            title: Text('${pageMistakes.length} أخطاء'),
            children: pageMistakes
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: m.buildSummaryTile(
                        onTap: () => showMistakeDetailDialog(m),
                      ),
                    ))
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  // Student: flat summary tiles
  Widget get buildStudentMistakeTiles {
    return Column(
      children: loadedMistakes
          .map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: m.buildSummaryTile(
                  onTap: () => showMistakeDetailDialog(m),
                ),
              ))
          .toList(),
    );
  }

  // Shared detail dialog (read-only for both roles)
  void showMistakeDetailDialog(QuranMistake mistake) {
    final hasComment = mistake.hasComment;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: getMistakeColor(mistake.type).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getMistakeIcon(mistake.type),
                  color: getMistakeColor(mistake.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mistake.type.arabicLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: getMistakeColor(mistake.type),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow(Icons.menu_book, 'الصفحة', mistake.pageNumber),
              _dialogRow(Icons.format_list_numbered, 'الآية',
                  mistake.ayahNumber),
              if (mistake.wordText?.isNotEmpty ?? false)
                _dialogRow(
                    Icons.text_fields, 'الكلمة', mistake.wordText!),
              if (hasComment) ...[
                const Divider(height: 16),
                const Text(
                  'ملاحظة المحفّظ:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mistake.correctionNote!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, Object value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppThemeConstants.grey500),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('$value'),
        ],
      ),
    );
  }

  // ── Mushaf button ──────────────────────────────────────────────────────────
  Widget get buildMoshafButton {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: openReadOnlyMoshaf,
        icon: const Icon(Icons.menu_book),
        label: const Text('فتح المصحف'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.success,
          foregroundColor: AppThemeConstants.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget? buildBottomNavigationBar({
    required bool isMohaffez,
    required bool isStudent,
    required SessionModel session,
  }) {
    // Mohaffez: complete session button
    if (isMohaffez && session.status == 'accepted') {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => context.push(
              '/complete-session/${session.id}',
              extra: {
                'studentName': session.studentName,
                'previousHifz': session.hifzAssignment,
                'previousMuraja': session.murajaAssignment,
              },
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('إتمام الجلسة'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppThemeConstants.secondary, width: 2),
              foregroundColor: AppThemeConstants.secondary,
            ),
          ),
        ),
      );
    }

    // Student: cancel button + refund policy banner
    if (isStudent &&
        session.status == 'accepted' &&
        session.sessionDate != null &&
        session.sessionDate!.isAfter(DateTime.now())) {
      final hoursUntil =
          session.sessionDate!.difference(DateTime.now()).inHours;

      final String refundPolicy;
      final Color policyColor;

      if (hoursUntil >= 24) {
        refundPolicy = 'استرداد كامل للمبلغ';
        policyColor = AppThemeConstants.success;
      } else if (hoursUntil >= 2) {
        refundPolicy = 'استرداد جزئي 50% من المبلغ';
        policyColor = AppThemeConstants.warning;
      } else {
        refundPolicy = 'لا يوجد استرداد للمبلغ';
        policyColor = AppThemeConstants.error;
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: policyColor.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: policyColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    refundPolicy,
                    style: TextStyle(color: policyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showCancellationDialog(session, refundPolicy),
                  icon: const Icon(Icons.cancel),
                  label: const Text('إلغاء الجلسة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isStudent &&
        session.status == 'completed' &&
        session.teacherRating == 0) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => navigateToRating(session),
              icon: const Icon(Icons.star, color: AppThemeConstants.white),
              label: const Text(
                'تقييم الجلسة',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.accentAmber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      );
    }

    return null;
  }
}

// ─── Private widgets ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppThemeConstants.grey600),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppThemeConstants.grey700,
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _AssignmentCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Object value;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppThemeConstants.grey600),
        ),
      ],
    );
  }
}

